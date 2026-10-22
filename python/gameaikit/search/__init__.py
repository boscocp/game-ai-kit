"""Search over a graph, the tier-1 half of `ai_search`, standard library only.

Only the piece another technique needs data from lives here so far:

    flood.py    Dijkstra to every cell within a cost: how far a sound travels

`spec/vectors/search/flood-*.json` holds this and `CostFlood` to the same
answers. The four route searches are checked from GDScript alone.
"""

from . import flood
