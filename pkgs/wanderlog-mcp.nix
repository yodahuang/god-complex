{
  buildNpmPackage,
  fetchFromGitHub,
  lib,
  nodejs_22,
}:
buildNpmPackage rec {
  pname = "wanderlog-mcp";
  version = "0.3.1";

  src = fetchFromGitHub {
    owner = "shaikhspeare";
    repo = "wanderlog-mcp";
    rev = "v${version}";
    hash = "sha256-CqDnx8uDvkQ/3uXLVd97j9oMZ1PdSkbRTL1F6U6G+aU=";
  };

  npmDepsHash = "sha256-3lLcZxvMQYi8U3Czxn3eSvvAumSZAwjIc9PjcJbSSmA=";
  nodejs = nodejs_22;

  meta = {
    description = "MCP server for Wanderlog";
    homepage = "https://github.com/shaikhspeare/wanderlog-mcp";
    license = lib.licenses.mit;
    mainProgram = "wanderlog-mcp";
  };
}
