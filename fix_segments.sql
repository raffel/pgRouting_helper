-- Wrapper for shortest_path() function to find the shortest route between two points
CREATE OR REPLACE FUNCTION dijkstra(
    geom_table varchar, source int4, target int4)
    RETURNS SETOF GEOMS AS
$$
DECLARE
    r record;
    path_result record;
    v_id integer;
    e_id integer;
    geom geoms;
    id integer;
BEGIN
    id := 0;
    FOR path_result IN EXECUTE 'SELECT gid,the_geom FROM ' ||
          'shortest_path(''SELECT gid AS id, start_id::integer AS source, end_id::integer AS target, ' || 
          'length(the_geom)::double precision AS cost FROM ' ||
      quote_ident(geom_table) || ''', ' || quote_literal(source) ||
          ' , ' || quote_literal(target) || ' , false, false), ' ||
          quote_ident(geom_table) || ' WHERE edge_id = gid '
        LOOP
            geom.gid      := path_result.gid;
            geom.the_geom := path_result.the_geom;
            id            := id + 1;
            geom.id       := id;
            RETURN NEXT geom;
        END LOOP;
    RETURN;
END;
$$ LANGUAGE 'plpgsql' VOLATILE STRICT;

-- Returns records for the route from start to end with correct directions
CREATE OR REPLACE FUNCTION calc_route(
    geom_table varchar, start_id int, end_id int)
    RETURNS SETOF record AS
$$
DECLARE
    r record;
    id int;
    prev int;
    i int;
BEGIN
    prev := 0;
    id   := start_id;
    FOR r IN EXECUTE 'SELECT start_id, end_id, route.* ' ||
      'FROM ' || quote_ident(geom_table) || ' JOIN ' ||
      '(SELECT * FROM dijkstra(' || quote_literal(geom_table) || ',' || start_id || ', ' || end_id || ')) AS route ' ||
      'ON ' || quote_ident(geom_table) || '.gid = route.gid ORDER BY route.id; '
    LOOP
        IF (r.start_id = id AND r.end_id <> prev) THEN
            RETURN NEXT r;
        ELSIF (r.end_id = id AND r.start_id <> prev) THEN
            i           := r.end_id;
            r.end_id    := r.start_id;
            r.start_id  := i;
            r.the_geom  := ST_Reverse(r.the_geom);
            RETURN NEXT r;
        ELSE
            RAISE NOTICE 'error: record % % %', r.start_id, r.end_id, r.id;
            RETURN;
        END IF;
        prev := r.start_id;
        id   := r.end_id;
    END LOOP;
    RETURN;
END;
$$ LANGUAGE 'plpgsql' VOLATILE STRICT;

