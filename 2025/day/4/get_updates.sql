CREATE OR REPLACE MACRO get_updates() AS TABLE
SELECT 
    g.*,
    string_split((
        COALESCE((SELECT x.v FROM grid x WHERE x.r = (g.r-1) AND (x.c = g.c-1)), '') ||
        COALESCE((SELECT x.v FROM grid x WHERE x.r = (g.r-1) AND (x.c = g.c)), '') ||
        COALESCE((SELECT x.v FROM grid x WHERE x.r = (g.r-1) AND (x.c = g.c+1)), '') ||
        COALESCE((SELECT x.v FROM grid x WHERE x.r = g.r AND (x.c = g.c-1)), '') ||
        g.v ||
        COALESCE((SELECT x.v FROM grid x WHERE x.r = g.r AND (x.c = g.c+1)), '') ||
        COALESCE((SELECT x.v FROM grid x WHERE x.r = (g.r+1) AND (x.c = g.c-1)), '') ||
        COALESCE((SELECT x.v FROM grid x WHERE x.r = (g.r+1) AND (x.c = g.c)), '') ||
        COALESCE((SELECT x.v FROM grid x WHERE x.r = (g.r+1) AND (x.c = g.c+1)), '')
    ), '') AS area
FROM grid g
WHERE g.v = '@' AND len(list_filter(area, x -> x = '@')) <= 4;

