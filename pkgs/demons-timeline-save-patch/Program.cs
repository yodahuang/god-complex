// Patches Easy Save 3's ES3IO in Demons' Timeline's Assembly-CSharp-firstpass.dll
// so saves work under CrossOver/Wine.
//
// Under Wine, File.Delete throws `IOException: Success` and leaves the file
// delete-pending (still visible to File.Exists from inside Wine) for an
// unbounded time. ES3's CommitBackup deletes and recreates SaveFile.es3.tmp.bak
// on every ES3.Save call, so the second call in a save trips over the pending
// file and, because the game saves one key per call inside a single task, the
// first failure drops every remaining key.
//
// Fix: for file saves, CommitBackup now just overwrites SaveFile.es3 with
// SaveFile.es3.tmp (File.Copy(tmp, full, overwrite: true)) — no delete, no
// move, no .bak. The .tmp is left in place; ES3 truncates it on the next save.
// DeleteFile/MoveFile additionally wait briefly for a pending operation to land
// before rethrowing, for ES3's other callers.
//
// Always patches from the pristine <dll>.orig (created on first run), so
// re-running after a patcher change or a Steam update is safe.
// Usage: patcher <Assembly-CSharp-firstpass.dll> [--check]
using Mono.Cecil;
using Mono.Cecil.Cil;

if (args.Length < 1)
{
    Console.Error.WriteLine("usage: patcher <Assembly-CSharp-firstpass.dll> [--check]");
    return 2;
}

var path = args[0];
var checkOnly = args.Contains("--check");

var resolver = new DefaultAssemblyResolver();
resolver.AddSearchDirectory(Path.GetDirectoryName(Path.GetFullPath(path))!);

// An empty type added to the module marks which patch revision is applied.
const string MarkerNs = "DemonsTimelineSavePatch";
const string MarkerName = "V3";

bool HasMarker(AssemblyDefinition a) => a.MainModule.GetType($"{MarkerNs}.{MarkerName}") != null;

var backup = path + ".orig";
if (checkOnly)
{
    using var current = AssemblyDefinition.ReadAssembly(
        new MemoryStream(File.ReadAllBytes(path)), new ReaderParameters { AssemblyResolver = resolver });
    var patched = HasMarker(current);
    Console.WriteLine(patched ? $"patched ({MarkerName})" : "not patched");
    return patched ? 0 : 1;
}

// A Steam update replaces the dll; the stale .orig must not win over it.
if (File.Exists(backup))
{
    using var current = AssemblyDefinition.ReadAssembly(
        new MemoryStream(File.ReadAllBytes(path)), new ReaderParameters { AssemblyResolver = resolver });
    var currentIsPatched = HasMarker(current)
        || current.MainModule.GetType("ES3Internal.ES3IO")!.Methods
            .Single(m => m.Name == "DeleteFile" && m.Parameters.Count == 1).Body.HasExceptionHandlers;
    if (!currentIsPatched)
    {
        File.Copy(path, backup, overwrite: true);
        Console.WriteLine($"dll looks freshly updated; refreshed {backup}");
    }
}
else
{
    File.Copy(path, backup);
    Console.WriteLine($"original saved to {backup}");
}

// Read into memory so the target path can be overwritten afterwards.
var bytes = File.ReadAllBytes(backup);
using var asm = AssemblyDefinition.ReadAssembly(
    new MemoryStream(bytes), new ReaderParameters { AssemblyResolver = resolver });
var module = asm.MainModule;

var es3io = module.GetType("ES3Internal.ES3IO")
    ?? throw new Exception("ES3Internal.ES3IO not found; not an Easy Save 3 assembly?");
var deleteFile = es3io.Methods.Single(m => m.Name == "DeleteFile" && m.Parameters.Count == 1);
var moveFile = es3io.Methods.Single(m => m.Name == "MoveFile" && m.Parameters.Count == 2);
var fileExists = es3io.Methods.Single(m => m.Name == "FileExists" && m.Parameters.Count == 1);
if (deleteFile.Body.HasExceptionHandlers)
    throw new Exception($"{backup} is already patched; restore a pristine dll (Steam: verify files) first");

// Reuse the original File.Delete / File.Move references so the patched IL binds
// to the game's own mscorlib rather than the patcher's runtime.
MethodReference OriginalCall(MethodDefinition m, string name) =>
    m.Body.Instructions
        .Where(i => i.OpCode == OpCodes.Call && i.Operand is MethodReference r
                    && r.DeclaringType.FullName == "System.IO.File" && r.Name == name)
        .Select(i => (MethodReference)i.Operand)
        .Single();

var fileDelete = OriginalCall(deleteFile, "Delete");
var fileMove = OriginalCall(moveFile, "Move");

// Wine can report a delete/move as failed while the change is still pending
// (another handle, e.g. Steam Cloud's watcher, keeps the file alive briefly);
// ES3's next CommitBackup then trips over the lingering .tmp.bak. On an
// exception, poll the filesystem for up to PollTries * PollMs for the operation
// to land before giving up and rethrowing.
const int PollTries = 40;
const int PollMs = 50;

var sleep = new MethodReference("Sleep", module.TypeSystem.Void,
    new TypeReference("System.Threading", "Thread", module, fileDelete.DeclaringType.Scope))
{
    HasThis = false,
};
sleep.Parameters.Add(new ParameterDefinition(module.TypeSystem.Int32));

// Rewrites `m` as: [guard] try { <call> } catch { i = 0; while (<pending>) {
// if (i >= PollTries) throw; Thread.Sleep(PollMs); i++; } }
void Rewrite(MethodDefinition m, Action<ILProcessor, Instruction>? guard,
    Action<ILProcessor> call, Action<ILProcessor, Instruction> branchIfDone)
{
    var body = m.Body;
    body.Instructions.Clear();
    body.ExceptionHandlers.Clear();
    body.Variables.Clear();
    var i = new VariableDefinition(module.TypeSystem.Int32);
    body.Variables.Add(i);
    body.InitLocals = true;
    var il = body.GetILProcessor();

    var ret = il.Create(OpCodes.Ret);
    var handlerStart = il.Create(OpCodes.Pop);
    var loop = il.Create(OpCodes.Nop);
    var doSleep = il.Create(OpCodes.Ldc_I4, PollMs);
    var handlerLeave = il.Create(OpCodes.Leave, ret);

    guard?.Invoke(il, ret);
    var tryStart = il.Create(OpCodes.Nop);
    il.Append(tryStart);
    call(il);
    il.Append(il.Create(OpCodes.Leave, ret));

    il.Append(handlerStart);
    il.Append(il.Create(OpCodes.Ldc_I4_0));
    il.Append(il.Create(OpCodes.Stloc, i));
    il.Append(loop);
    branchIfDone(il, handlerLeave);
    il.Append(il.Create(OpCodes.Ldloc, i));
    il.Append(il.Create(OpCodes.Ldc_I4, PollTries));
    il.Append(il.Create(OpCodes.Blt, doSleep));
    il.Append(il.Create(OpCodes.Rethrow));
    il.Append(doSleep);
    il.Append(il.Create(OpCodes.Call, sleep));
    il.Append(il.Create(OpCodes.Ldloc, i));
    il.Append(il.Create(OpCodes.Ldc_I4_1));
    il.Append(il.Create(OpCodes.Add));
    il.Append(il.Create(OpCodes.Stloc, i));
    il.Append(il.Create(OpCodes.Br, loop));
    il.Append(handlerLeave);
    il.Append(ret);

    body.ExceptionHandlers.Add(new ExceptionHandler(ExceptionHandlerType.Catch)
    {
        CatchType = module.TypeSystem.Object,
        TryStart = tryStart,
        TryEnd = handlerStart,
        HandlerStart = handlerStart,
        HandlerEnd = ret,
    });
}

// DeleteFile(p): if (!FileExists(p)) return; done when !FileExists(p).
Rewrite(deleteFile,
    (il, ret) =>
    {
        il.Append(il.Create(OpCodes.Ldarg_0));
        il.Append(il.Create(OpCodes.Call, fileExists));
        il.Append(il.Create(OpCodes.Brfalse, ret));
    },
    il =>
    {
        il.Append(il.Create(OpCodes.Ldarg_0));
        il.Append(il.Create(OpCodes.Call, fileDelete));
    },
    (il, done) =>
    {
        il.Append(il.Create(OpCodes.Ldarg_0));
        il.Append(il.Create(OpCodes.Call, fileExists));
        il.Append(il.Create(OpCodes.Brfalse, done));
    });

// MoveFile(s, d): done when !FileExists(s) && FileExists(d).
Rewrite(moveFile, null,
    il =>
    {
        il.Append(il.Create(OpCodes.Ldarg_0));
        il.Append(il.Create(OpCodes.Ldarg_1));
        il.Append(il.Create(OpCodes.Call, fileMove));
    },
    (il, done) =>
    {
        var notDone = il.Create(OpCodes.Nop);
        il.Append(il.Create(OpCodes.Ldarg_0));
        il.Append(il.Create(OpCodes.Call, fileExists));
        il.Append(il.Create(OpCodes.Brtrue, notDone));
        il.Append(il.Create(OpCodes.Ldarg_1));
        il.Append(il.Create(OpCodes.Call, fileExists));
        il.Append(il.Create(OpCodes.Brtrue, done));
        il.Append(notDone);
    });

// CommitBackup: prepend
//   if (settings.location == ES3.Location.File) {
//       File.Copy(settings.FullPath + ".tmp", settings.FullPath, true); return; }
// ahead of the original body (which still handles PlayerPrefs etc).
{
    var commit = es3io.Methods.Single(m => m.Name == "CommitBackup" && m.Parameters.Count == 1);
    var calls = commit.Body.Instructions
        .Where(i => (i.OpCode == OpCodes.Call || i.OpCode == OpCodes.Callvirt) && i.Operand is MethodReference)
        .Select(i => (MethodReference)i.Operand).ToList();
    var getLocation = calls.First(r => r.Name == "get_location");
    var getFullPath = calls.First(r => r.Name == "get_FullPath");
    var concat2 = calls.First(r => r.Name == "Concat" && r.Parameters.Count == 2);

    var fileCopy2 = OriginalCall(es3io.Methods.Single(m => m.Name == "CopyFile" && m.Parameters.Count == 2), "Copy");
    var fileCopy3 = new MethodReference("Copy", module.TypeSystem.Void, fileCopy2.DeclaringType) { HasThis = false };
    fileCopy3.Parameters.Add(new ParameterDefinition(module.TypeSystem.String));
    fileCopy3.Parameters.Add(new ParameterDefinition(module.TypeSystem.String));
    fileCopy3.Parameters.Add(new ParameterDefinition(module.TypeSystem.Boolean));

    var il = commit.Body.GetILProcessor();
    var original = commit.Body.Instructions[0];
    // ES3.Location.File == 0, matching the original's `brtrue` on get_location.
    il.InsertBefore(original, il.Create(OpCodes.Ldarg_0));
    il.InsertBefore(original, il.Create(OpCodes.Callvirt, getLocation));
    il.InsertBefore(original, il.Create(OpCodes.Brtrue, original));
    il.InsertBefore(original, il.Create(OpCodes.Ldarg_0));
    il.InsertBefore(original, il.Create(OpCodes.Callvirt, getFullPath));
    il.InsertBefore(original, il.Create(OpCodes.Ldstr, ".tmp"));
    il.InsertBefore(original, il.Create(OpCodes.Call, concat2));
    il.InsertBefore(original, il.Create(OpCodes.Ldarg_0));
    il.InsertBefore(original, il.Create(OpCodes.Callvirt, getFullPath));
    il.InsertBefore(original, il.Create(OpCodes.Ldc_I4_1));
    il.InsertBefore(original, il.Create(OpCodes.Call, fileCopy3));
    il.InsertBefore(original, il.Create(OpCodes.Ret));
}

module.Types.Add(new TypeDefinition(MarkerNs, MarkerName,
    TypeAttributes.NotPublic | TypeAttributes.Abstract | TypeAttributes.Sealed, module.TypeSystem.Object));

var outPath = path + ".patched";
asm.Write(outPath);
File.Move(outPath, path, overwrite: true);
Console.WriteLine($"patched {path}");
return 0;
