# gameaikit

Game AI techniques in plain Python, the standard library and nothing else:
search, adversarial search, planning from PDDL, fuzzy control, steering,
utility choice, perception and belief, an opponent model, a validator for a
language model's replies, and the gradient descent that trains the models
the Godot half reads.

Each technique is the tier-1 half of a Godot addon of the same kit, held to
the same answers by shared test vectors. It runs, and is tested, without an
engine.

```python
from gameaikit import techniques

for name, found in techniques.available().items():
    print(f"{name:26} {found.about}")
```

```python
from gameaikit.utility import aim

head = aim.Zone("head", 2.0, (0.0, 1.65), [(-0.12, 1.5, 0.12, 1.8)], 1.0)
torso = aim.Zone("torso", 1.0, (0.0, 1.175), [(-0.2, 0.85, 0.2, 1.5)], 1.0)
print(aim.choose([head, torso], 0.5).aimed)   # 1: far away, the torso
```

## Your own technique

Declare it in your package's `pyproject.toml` and `techniques.available()`
lists it beside the kit's:

```toml
[project.entry-points."gameaikit.techniques"]
my-search = "my_package.search:MySearch"
```

A name the kit already uses is refused rather than shadowed.

## Licence

Apache-2.0. `LICENSE` and `NOTICE` travel with the wheel, in its
`.dist-info/licenses/`.
