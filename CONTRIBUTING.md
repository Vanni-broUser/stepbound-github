# Contributing

## GitLab workflow

The canonical repository is hosted on GitLab. Keep `main` protected and require a successful pipeline before merge. Direct pushes to `main` should be disabled for developers.

Use short-lived branches and merge requests:

- `feat/<topic>` for features
- `fix/<topic>` for fixes
- `chore/<topic>` for maintenance

Commit messages follow Conventional Commits, for example `feat(core): add hearing propagation`.

## Local quality gate

Before opening a merge request, run:

```bash
dart format .
flutter analyze --fatal-infos --fatal-warnings
flutter test
```

The shared GitLab runner executes the same checks. Release signing must run only on a protected local runner with masked, protected variables.

## Definition of done

A change is complete when its behavior is covered by tests, formatting and analysis pass, the GitLab pipeline is green, and relevant documentation is updated.
