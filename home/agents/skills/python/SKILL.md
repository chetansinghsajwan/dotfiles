---
name: python
description: Python code style rules. Use when writing, editing or reviewing Python code.
---

# Python

If a repo has its own Python conventions (docs/style-guide.md, pyproject.toml, ruff config), read them first and follow them where they conflict.

## Call arguments

- **Always pass arguments by name.** Write `some_function(arg1="hello", arg2=3)`, never `some_function("hello", 3)`.
- **Applies to every call:** functions, methods, constructors, and calls into the standard library and third-party code.
- **Unavoidable exceptions:** positional-only parameters (`/` in the signature) and C-implemented builtins that reject keywords (for example `len(x)`, `isinstance(x, T)`). Pass those positionally.

```python
# good
user = create_user(name="Asha", email="asha@example.com", active=True)

# bad
user = create_user("Asha", "asha@example.com", True)
```

## Docstrings

- **Use Google style** with triple double quotes: a one-line summary, then `Args:`, `Returns:`, `Raises:` sections as needed.
- **Skip types in `Args:`** when the signature has type hints. Write `width: Horizontal side length.`
- **Explain purpose and reason**, in simple language, not what each line does. Skip sections that add nothing, such as `Args:` for a single obvious parameter.
- **Cover public code:** every public module, class and function. Skip trivial private helpers.
- **Ruff:** set `convention = "google"` under `[tool.ruff.lint.pydocstyle]` if the repo has no docstring config.

```python
def area(width: float, height: float) -> float:
    """Return the area of a rectangle.

    Args:
        width: Horizontal side length.
        height: Vertical side length.

    Returns:
        The product of width and height.

    Raises:
        ValueError: If either side is negative.
    """
```

## Imports within a package

- **Use relative imports for modules in the same package or its sub-directories.** Write `from .path import name`, not `from package.path import name`.
- **Go down, not up, with the dot form:** `from .sub.module import thing` for a sibling or child module. Use `from ..x import y` only to reach the parent package.
- **Absolute imports are for code outside the package:** the standard library and third-party packages.

```python
# inside package/core/service.py
from .models import User           # sibling module
from .helpers.text import slugify  # module in a sub-directory
import json                        # standard library stays absolute
```
