/* Starts its arguments as a child process and stays its parent, so macOS
 * attributes the child's network access to this binary's identity. */
#include <signal.h>
#include <spawn.h>
#include <stdio.h>
#include <sys/wait.h>
#include <unistd.h>

extern char **environ;
static pid_t child;

static void forward(int sig) {
  if (child > 0) kill(child, sig);
}

int main(int argc, char **argv) {
  if (argc < 2) {
    fprintf(stderr, "usage: %s program [args...]\n", argv[0]);
    return 2;
  }
  int sigs[] = {SIGTERM, SIGINT, SIGHUP, SIGQUIT, SIGUSR1, SIGUSR2};
  for (unsigned i = 0; i < sizeof sigs / sizeof *sigs; i++) signal(sigs[i], forward);
  int err = posix_spawnp(&child, argv[1], NULL, NULL, argv + 1, environ);
  if (err) {
    fprintf(stderr, "%s: cannot start %s: %d\n", argv[0], argv[1], err);
    return 127;
  }
  int status;
  while (waitpid(child, &status, 0) < 0) {}
  if (WIFEXITED(status)) return WEXITSTATUS(status);
  signal(WTERMSIG(status), SIG_DFL);
  raise(WTERMSIG(status));
  return 128 + WTERMSIG(status);
}
