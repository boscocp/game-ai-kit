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
- **Puny Characters**, by Shade, on OpenGameArt: <https://opengameart.org/content/puny-characters>,
  the archive `puny-characters.zip` (sha256
  971d7b07eea18fb2cce475cd6554a176ebf783bb064dec5a637ba33c7829320e). Its page
  gives the licence as CC0 and says "No need to give me credit". T33's walking
  sheets: 32-pixel frames, 24 across and one row per direction of eight.
- **Fighting character template Mustermann 2 (A001AAAA001) (karate)**, by
  Puffolotti, on OpenGameArt: <https://opengameart.org/node/97941>. Its page
  gives the licence as CC0, and its notice reads "Sprite created by
  Puffolotti Accident". T35's fighters: two sheets of the same 997 cels
  in two costumes, `Orangeblack.png` (sha256
  75175c4f2e40b842baf91f58d73eaef460b1a54438f922ab57bfbc45c4a39983) and
  `Blueehite.png` (sha256
  1aae40ed67db9ec0f400d9967f93b2957e44f38fc6815982c90bb31a7b3a2c2d), a grid
  of 35 cels across and 29 down. **The sheets are not committed** (ADR
  0015): each `fighters/` file is a strip of whole cels cut from one of
  them, listed below by cel number, which `make fighter-sheets` and `make
  fighter-strips` repeat from the downloads.

Each file is the pack's own, byte for byte, renamed to the role it plays --
bar the fighters' strips, which are cuts, and say which cels they hold. The
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
| `units/red/shield_walk.png` | Puny Characters | `Puny-Characters/Warrior-Red.png` | CC0 1.0 | c60c80dcad811b3ef0e0e8e1fa5f0d62e011b3e604f2bb2a78261f2dcae6c712 |
| `units/blue/shield_walk.png` | Puny Characters | `Puny-Characters/Warrior-Blue.png` | CC0 1.0 | acc8db08577086f1520d74d0806a614833a1f7356ba8a560437fd4c59538cdbc |
| `units/red/soldier_walk.png` | Puny Characters | `Puny-Characters/Soldier-Red.png` | CC0 1.0 | b9a89aef6607463d9444b701c8b687e70b2499f9c44257da0d48d68e48f6faf4 |
| `units/blue/soldier_walk.png` | Puny Characters | `Puny-Characters/Soldier-Blue.png` | CC0 1.0 | ddcb515baaf2b5b7a4c569ba23d7490c3e5221bb5e97d760ce67ce9c261a543d |
| `checkers/red_man.png` | Boardgame Pack v2 | `PNG/Chips/chipRedWhite.png` | CC0 1.0 | 05cefc21baba589d6381d7b3ffa92b8f60307cfdaa3f2287ea69401f20801db0 |
| `checkers/white_man.png` | Boardgame Pack v2 | `PNG/Chips/chipWhite.png` | CC0 1.0 | 7669b71d23e44cf9f5b1fcb7f08e78c7fdfd4373e38a8e88ab098df156b58a49 |
| `checkers/crown.png` | Board Game Icons | `PNG/Default (64px)/crown_a.png` | CC0 1.0 | 471bc3b1948d6a72ef272fa82ecb9e53a6728d57fb48029599f44be5226ac0ba |
| `tictactoe/cross.png` | Game Icons | `PNG/White/2x/cross.png` | CC0 1.0 | 8293e3758e7df2eb1c5bb8d6979cccc826e66c28f8c703e6cbb0a54a3c0efc33 |
| `tictactoe/nought.png` | Board Game Icons | `PNG/Default (64px)/token.png` | CC0 1.0 | 8d123380791b61861fdaf841b87950bc189349fdd8e522a3daea984086f80fb6 |
| `fighters/lancer/idle.png` | Mustermann 2 | `Orangeblack.png`, cels 4, 5, 6, 7, 8, 9, 10, 11 | CC0 1.0 | 84ede3f437c93c2216332c5447b39e5aeff8f8ccb457ae6158ca2dca588381fa |
| `fighters/lancer/walk.png` | Mustermann 2 | `Orangeblack.png`, cels 416, 417, 418, 419, 420, 421, 422, 423, 424, 425, 426, 427 | CC0 1.0 | 046002cbf39337cec1c99caa71f035a5bba787cc4480cebe28789bc3d1cc50cd |
| `fighters/lancer/crouch.png` | Mustermann 2 | `Orangeblack.png`, cels 727, 728 | CC0 1.0 | 9c6e326d681140497a78ea7c454565d90408fad158a4dff039177f060a02fdd6 |
| `fighters/lancer/guard.png` | Mustermann 2 | `Orangeblack.png`, cels 345, 346, 347, 348 | CC0 1.0 | 03f59021b6a6721ae3f90e49013a154f664e6cb2cb539d7419d591e3be3d1b3e |
| `fighters/lancer/guard_crouching.png` | Mustermann 2 | `Orangeblack.png`, cels 845, 850, 855 | CC0 1.0 | 805f6a5eeba39a10b3600616e1035dc6a83cf7a35159f2bd6cfa1c210f4c09a5 |
| `fighters/lancer/hit.png` | Mustermann 2 | `Orangeblack.png`, cels 923, 924, 925, 926, 927 | CC0 1.0 | c68696c5863ab790af3c884a3d23e5ab6a3589c79812511e4e6854d9f1a2f40a |
| `fighters/lancer/down.png` | Mustermann 2 | `Orangeblack.png`, cels 948 | CC0 1.0 | fd8a4517d73a6493fce164e3c14ca031b686994cd1779636a81404ee4229a08b |
| `fighters/lancer/jab.png` | Mustermann 2 | `Orangeblack.png`, cels 16, 17, 18, 19, 20 | CC0 1.0 | 5505f86924714809ee48f41a8286d6111a61d42f95f5654758bebf2f0c72f9bf |
| `fighters/lancer/thrust.png` | Mustermann 2 | `Orangeblack.png`, cels 63, 64, 65, 66, 67, 68, 69, 70 | CC0 1.0 | c0d95cfb423d8f0c3f8e059d1536affc36196356ebe4cd6a702286db67696277 |
| `fighters/lancer/shin_kick.png` | Mustermann 2 | `Orangeblack.png`, cels 148, 149, 150, 151, 152, 153, 154 | CC0 1.0 | b711e2e2da5c65d29ee73f14236154f632469baccd0d26e598374922a6fd0cd9 |
| `fighters/lancer/axe_kick.png` | Mustermann 2 | `Orangeblack.png`, cels 229, 230, 231, 232, 233, 234, 235, 236, 237, 238, 239 | CC0 1.0 | 33cfba220f7fc441be39ff8b426d4244f8078b0f78b4c8c1cea97ccebc66dbd6 |
| `fighters/lancer/low_jab.png` | Mustermann 2 | `Orangeblack.png`, cels 728, 729, 730, 731, 732 | CC0 1.0 | c242569d063963dc0c78c61357551a60cd7fc9a31b0b5564d082f1738538d078 |
| `fighters/lancer/low_kick.png` | Mustermann 2 | `Orangeblack.png`, cels 790, 791, 792, 793, 794, 795, 796, 797 | CC0 1.0 | 40aeac25dbfcd7fad1c2abab37e2a92308ec9bf3171d0675cb83cd601eddff2c |
| `fighters/lancer/sweep.png` | Mustermann 2 | `Orangeblack.png`, cels 821, 822, 823, 824, 825, 826, 827, 828, 829 | CC0 1.0 | bfaa2aab0aeef3fc172ce1e1c66c2fb70878283652c9d211757abcdc998bef55 |
| `fighters/lancer/throw.png` | Mustermann 2 | `Orangeblack.png`, cels 518, 519, 520, 521, 522, 523, 524 | CC0 1.0 | fbe9f1a27a42e4a7d2e20fabaab631e508eb88e738c4f8f0206578d2138a205b |
| `fighters/dancer/idle.png` | Mustermann 2 | `Blueehite.png`, cels 4, 5, 6, 7, 8, 9, 10, 11 | CC0 1.0 | 9b8c2a3554f56f8329eaac672b9ee8091411c3827c52facf97d24d6e4d64c4dc |
| `fighters/dancer/walk.png` | Mustermann 2 | `Blueehite.png`, cels 416, 417, 418, 419, 420, 421, 422, 423, 424, 425, 426, 427 | CC0 1.0 | 0be28d709015d8a15a1f742d426f1cf110c5e74411751cd71e6f5797e1ce18d6 |
| `fighters/dancer/crouch.png` | Mustermann 2 | `Blueehite.png`, cels 727, 728 | CC0 1.0 | 4946cfbf90f18755d7f1ac4e5e0baa2472c0a785db3c076b78d5a95670363eb0 |
| `fighters/dancer/guard.png` | Mustermann 2 | `Blueehite.png`, cels 345, 346, 347, 348 | CC0 1.0 | 47a2f25f96fa629b8762c774b2f1e861e15aa97b9a1b17f24e41479cfb4f5e75 |
| `fighters/dancer/guard_crouching.png` | Mustermann 2 | `Blueehite.png`, cels 845, 850, 855 | CC0 1.0 | 86a2ee0014701e9a8062c81142a50b3cc1da0e92c299a83196886c45663802f7 |
| `fighters/dancer/hit.png` | Mustermann 2 | `Blueehite.png`, cels 923, 924, 925, 926, 927 | CC0 1.0 | 64b5ce424eb39b173d1ce0a5004fd862ada7b31ed2e8a36475052a0e1c2ad5c4 |
| `fighters/dancer/down.png` | Mustermann 2 | `Blueehite.png`, cels 948 | CC0 1.0 | 7b52f3b47c68d325393498ffd0560710aba501fa2a18cb44711242aede0c93cf |
| `fighters/dancer/jab.png` | Mustermann 2 | `Blueehite.png`, cels 359, 360, 361, 362, 363, 364, 365 | CC0 1.0 | 298b4ec523f00e34ce6be4a8d0a7e6aae5302af439c8eb00ef895968e5920744 |
| `fighters/dancer/straight.png` | Mustermann 2 | `Blueehite.png`, cels 369, 370, 371, 372, 373, 374, 375, 376 | CC0 1.0 | 7096d9660befa0fb9d26a643cb76f746f46ccc5ae90a1467573dc851b73ce3f1 |
| `fighters/dancer/snap_kick.png` | Mustermann 2 | `Blueehite.png`, cels 142, 143, 144, 145, 146, 147 | CC0 1.0 | d6d0571f0891c539ffe13dd77d2df8c9d51b6ce62aa082965354dc8daef19732 |
| `fighters/dancer/hop_kick.png` | Mustermann 2 | `Blueehite.png`, cels 187, 188, 189, 190, 191, 192, 193, 194, 195 | CC0 1.0 | ecfce6705e75753f5fae87d942c9b89e0474b75f775d5e8b77368ee4f85e8b08 |
| `fighters/dancer/low_jab.png` | Mustermann 2 | `Blueehite.png`, cels 735, 736, 737, 738, 739, 740 | CC0 1.0 | c1bc9b93c37afcf8af0e70f2dae605318c6ded66ec5740841a56d99ca2ffbaac |
| `fighters/dancer/low_kick.png` | Mustermann 2 | `Blueehite.png`, cels 869, 870, 871, 872, 873 | CC0 1.0 | 4e0697774333d87e979f37009459558f84cf9e695ae2b5e8876e1bc7e7e1d0c7 |
| `fighters/dancer/sweep.png` | Mustermann 2 | `Blueehite.png`, cels 810, 811, 812, 813, 814, 815, 816 | CC0 1.0 | 7ea01d9f8b333dbca9f4f15f7ce45d3aef6eaf297c7df3a251416686261f796f |
| `fighters/dancer/throw.png` | Mustermann 2 | `Blueehite.png`, cels 528, 532, 533, 534, 535, 536, 537 | CC0 1.0 | c9f37a4a6ca382366b5aaafd21096c25fc480c03d3dbb25fc95ef5dfcbd7ee70 |
