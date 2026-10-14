# Where the art came from

Every picture under `godot/assets/` is listed here **by path**, with the pack
it came from, its licence and its sha256. `check_license.py` reads this table
from git's index, and each of these is a finding:
- a committed picture with no row, or a row for a file that is not committed;
- a row whose licence is not CC0 1.0, or that is missing a cell;
- a committed picture whose sha256 is not its row's. A row attributes one
  file, not whatever is later written at its path.

T31 lets a person generate their own art. It does not go here: it goes to a
folder of its own that git ignores, which the game prefers when a file is
there. Overwriting a file listed here would change its sha256, and the gate
says so before it can be committed under the pack's name.

## The licence

Every file here is **CC0 1.0** (Creative Commons Zero), public domain
dedication: <https://creativecommons.org/publicdomain/zero/1.0/>. Credit is not
required. It is given anyway, because it is owed.

## The packs

- **Board Game Icons**, by Kenney (www.kenney.nl): <https://kenney.nl/assets/board-game-icons>
- **Boardgame Pack v2**, by Kenney (www.kenney.nl): <https://kenney.nl/assets/boardgame-pack>
- **Game Icons**, by Kenney (www.kenney.nl): <https://kenney.nl/assets/game-icons>
- **Tiny Battle 1.0**, by Kenney (www.kenney.nl): <https://kenney.nl/assets/tiny-battle>

Each file is the pack's own, byte for byte, renamed to the role it plays. The
packs were downloaded on 2026-10-14 from the pages above. Nothing was edited:
where a picture has see-through parts -- trees, a rock, a flag -- the game
lays it over open ground when it draws, rather than a second file doing it.

## The files

| path | pack | file in the pack | licence | sha256 |
|---|---|---|---|---|
| `terrain/plain.png` | Tiny Battle 1.0 | `Tiles/tile_0000.png` | CC0 1.0 | d4c692ef80ee97b3395b885ae07020d42a106683ff3650df240f8e972bd5a041 |
| `terrain/rough.png` | Tiny Battle 1.0 | `Tiles/tile_0197.png` | CC0 1.0 | 4d5373dff086813faceeed05e95cf60f5e2f9d8a8f09629ce0645da0752cd537 |
| `terrain/trees.png` | Tiny Battle 1.0 | `Tiles/tile_0112.png` | CC0 1.0 | 5851aa4e570978c70ad09c1b6daaf7e6d3633190fd45374f5340a9f3a631f597 |
| `terrain/wall.png` | Tiny Battle 1.0 | `Tiles/tile_0005.png` | CC0 1.0 | 3d27ccb7a5ee9367536cecdb855d90bf16ab00285294f5d6e2460306c2b505cd |
| `terrain/water.png` | Tiny Battle 1.0 | `Tiles/tile_0037.png` | CC0 1.0 | 197207fcedcc49bbaa7c38770eb53efb9f792cbc61dfd8f5636f8c43c4993cd0 |
| `terrain/bridge.png` | Tiny Battle 1.0 | `Tiles/tile_0130.png` | CC0 1.0 | af7d2750e216b54a788304ea758298039b3993f3eea8c0fad5df4a1b1b0cadbe |
| `terrain/node.png` | Tiny Battle 1.0 | `Tiles/tile_0016.png` | CC0 1.0 | b6914abcd3f8c0aa9ae411e16ef3cccb366556e2c2742c1d8321f98bb7da8047 |
| `units/red/runner.png` | Tiny Battle 1.0 | `Tiles/tile_0149.png` | CC0 1.0 | 81936221fb775dfdd02f70118d273309037d40e312f6a2d65b8bd9e70beb0214 |
| `units/red/shield.png` | Tiny Battle 1.0 | `Tiles/tile_0161.png` | CC0 1.0 | 65a25c501e4351fa060025a8d90f95f0b678b7bec234feeb33618442421e6140 |
| `units/red/mortar.png` | Tiny Battle 1.0 | `Tiles/tile_0153.png` | CC0 1.0 | 1584333dc74b0671fbacb70f73100de8c27b4f8c9bc0a7af229c3b7399c41afc |
| `units/red/wader.png` | Tiny Battle 1.0 | `Tiles/tile_0157.png` | CC0 1.0 | d186cd1ea727f21b72eba5150dc280695eb8ae8b866ab926a11377d02b988649 |
| `units/red/ram.png` | Tiny Battle 1.0 | `Tiles/tile_0152.png` | CC0 1.0 | 91b51cf0e879defde7540d31108b7125f6efdd15de242de42ffc3184d674196f |
| `units/red/bolt_tower.png` | Tiny Battle 1.0 | `Tiles/tile_0068.png` | CC0 1.0 | ea0a159bd1851073b9c1f5665158cba4116d5b79eb99aaa018ef150c413012b1 |
| `units/red/watchtower.png` | Tiny Battle 1.0 | `Tiles/tile_0067.png` | CC0 1.0 | 7b466d448f59d206cc3572f04361fa62d86db771fe25cd99da7ae79713917536 |
| `units/red/workshop.png` | Tiny Battle 1.0 | `Tiles/tile_0065.png` | CC0 1.0 | 90e9fe9d60ba0e0e92a002373a20167f4f041a0410894338f20135c9b58c5a9c |
| `units/red/soldier.png` | Tiny Battle 1.0 | `Tiles/tile_0160.png` | CC0 1.0 | 11968dcb47a97e624059afae8936bc960e5377652e5d92dfbc05a2afd0289246 |
| `units/blue/runner.png` | Tiny Battle 1.0 | `Tiles/tile_0131.png` | CC0 1.0 | ea618de3ee2fc363ac3a4db20a9230e5ca7962d3ac01b448539901c46cf54216 |
| `units/blue/shield.png` | Tiny Battle 1.0 | `Tiles/tile_0143.png` | CC0 1.0 | a1cbb5a7abfc7aa949550eb3e66dbd3072cee7cf17f2f7ac28db4a71d600c8dd |
| `units/blue/mortar.png` | Tiny Battle 1.0 | `Tiles/tile_0135.png` | CC0 1.0 | fa4088b3d84cd6e0b7812d88fed295a5af33c9f543fb7cafa556c9e9371e9f61 |
| `units/blue/wader.png` | Tiny Battle 1.0 | `Tiles/tile_0139.png` | CC0 1.0 | bf14d2f7ee0f83ac098dd7d930a9719c04599a020739d8f43a6b2792f61baaf8 |
| `units/blue/ram.png` | Tiny Battle 1.0 | `Tiles/tile_0134.png` | CC0 1.0 | 980b0444376be0d685184252fb9dec287fb2ac544782bc413e85aed2522b617c |
| `units/blue/bolt_tower.png` | Tiny Battle 1.0 | `Tiles/tile_0050.png` | CC0 1.0 | 7b477a0defe2e58d7f6a76a399a6c160368b0e8d7fd7f78ae48046198969f584 |
| `units/blue/watchtower.png` | Tiny Battle 1.0 | `Tiles/tile_0049.png` | CC0 1.0 | 827407d8d0fdecf6a292a01d72946d2ea3a16e0084bd7b727efb406b9f147ced |
| `units/blue/workshop.png` | Tiny Battle 1.0 | `Tiles/tile_0047.png` | CC0 1.0 | f2f919bb5b951c5cc2beeb247052f233024d4a946f4a2ab90405af21672e7875 |
| `units/blue/soldier.png` | Tiny Battle 1.0 | `Tiles/tile_0142.png` | CC0 1.0 | 32f933bec7c2d0e08fe6718c9bfbf0e2b303403e1870688a45cd1ab11c052748 |
| `checkers/red_man.png` | Boardgame Pack v2 | `PNG/Chips/chipRedWhite.png` | CC0 1.0 | 05cefc21baba589d6381d7b3ffa92b8f60307cfdaa3f2287ea69401f20801db0 |
| `checkers/white_man.png` | Boardgame Pack v2 | `PNG/Chips/chipWhite.png` | CC0 1.0 | 7669b71d23e44cf9f5b1fcb7f08e78c7fdfd4373e38a8e88ab098df156b58a49 |
| `checkers/crown.png` | Board Game Icons | `PNG/Default (64px)/crown_a.png` | CC0 1.0 | 471bc3b1948d6a72ef272fa82ecb9e53a6728d57fb48029599f44be5226ac0ba |
| `tictactoe/cross.png` | Game Icons | `PNG/White/2x/cross.png` | CC0 1.0 | 8293e3758e7df2eb1c5bb8d6979cccc826e66c28f8c703e6cbb0a54a3c0efc33 |
| `tictactoe/nought.png` | Board Game Icons | `PNG/Default (64px)/token.png` | CC0 1.0 | 8d123380791b61861fdaf841b87950bc189349fdd8e522a3daea984086f80fb6 |
