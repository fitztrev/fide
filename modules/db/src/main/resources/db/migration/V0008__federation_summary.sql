CREATE OR REPLACE FUNCTION AVERAGE (
V1 NUMERIC,
V2 NUMERIC,
V3 NUMERIC)
RETURNS NUMERIC
AS $FUNCTION$
DECLARE
    COUNT NUMERIC;
    TOTAL NUMERIC;
BEGIN
    COUNT=0;
    TOTAL=0;
    IF V1 IS NOT NULL THEN COUNT=COUNT+1; TOTAL=TOTAL+V1; END IF;
    IF V2 IS NOT NULL THEN COUNT=COUNT+1; TOTAL=TOTAL+V2; END IF;
    IF V3 IS NOT NULL THEN COUNT=COUNT+1; TOTAL=TOTAL+V3; END IF;
    RETURN TOTAL/COUNT;
    EXCEPTION WHEN DIVISION_BY_ZERO THEN RETURN NULL;
END
$FUNCTION$ LANGUAGE PLPGSQL;

CREATE OR REPLACE VIEW fed_sum_1 as SELECT federations.id, COUNT(players.id) as players, ROUND(avg(players.standard)) as avg_standard, ROUND(avg(players.rapid)) as avg_rapid, ROUND(avg(players.blitz)) as avg_blitz, COUNT(COALESCE(players.standard, NULL)) as standard_players, COUNT(COALESCE(players.rapid, NULL)) as rapid_players, COUNT(COALESCE(players.blitz, NULL)) as blitz_players
FROM players, federations
WHERE players.federation_id = federations.id AND players.active = true
GROUP BY federations.id;

CREATE OR REPLACE VIEW fed_sum_2 AS SELECT *, ROUND(average(fs.avg_standard, fs.avg_rapid, fs.avg_blitz)) as avg_rating from fed_sum_1 as fs;

CREATE OR REPLACE VIEW fed_with_ranking AS SELECT federations.id, players.standard, players.rapid, players.blitz,
rank() OVER (
    PARTITION BY federations.id
    ORDER BY players.standard DESC NULLS LAST
        ) as standard_rank,
rank() OVER (
    PARTITION BY federations.id
    ORDER BY players.rapid DESC NULLS LAST
        ) as rapid_rank,

rank() OVER (
    PARTITION BY federations.id
    ORDER BY players.blitz DESC NULLS LAST
        ) as blitz_rank
FROM players, federations
WHERE players.federation_id = federations.id AND players.active = true;

-- average top 10 rating
create or replace view fed_with_avg_top_10 as
select t1.id, t1.avg_top_standard, t2.avg_top_rapid, t3.avg_top_blitz
FROM
(SELECT fed_with_ranking.id, ROUND(avg(standard)) as avg_top_standard
    FROM fed_with_ranking
    WHERE fed_with_ranking.standard_rank <= 10
    GROUP BY fed_with_ranking.id) as t1
LEFT JOIN
(SELECT fed_with_ranking.id, ROUND(avg(rapid)) as avg_top_rapid
    FROM fed_with_ranking
    WHERE fed_with_ranking.rapid_rank <= 10
    GROUP BY fed_with_ranking.id) as t2
ON t1.id = t2.id
LEFT JOIN
(SELECT fed_with_ranking.id, ROUND(avg(blitz)) as avg_top_blitz
    FROM fed_with_ranking
    WHERE fed_with_ranking.blitz_rank <= 10
    GROUP BY fed_with_ranking.id) as t3
ON t1.id = t3.id;

-- average top 10 rating with ranking
CREATE OR REPLACE VIEW fed_with_avg_top_10_ranking AS SELECT fed_with_avg_top_10.id, fed_with_avg_top_10.avg_top_standard, fed_with_avg_top_10.avg_top_rapid, fed_with_avg_top_10.avg_top_blitz,
rank() OVER (
    ORDER BY fed_with_avg_top_10.avg_top_standard DESC NULLS LAST
        ) as avg_top_standard_rank,
rank() OVER (
    ORDER BY fed_with_avg_top_10.avg_top_rapid DESC NULLS LAST
        ) as avg_top_rapid_rank,

rank() OVER (
    ORDER BY fed_with_avg_top_10.avg_top_blitz DESC NULLS LAST
        ) as avg_top_blitz_rank
FROM fed_with_avg_top_10;

create or replace view fed_sum as
select f1.*, f2.avg_top_standard, f2.avg_top_rapid, f2.avg_top_blitz, f2.avg_top_standard_rank, f2.avg_top_rapid_rank, f2.avg_top_blitz_rank
from fed_sum_2 as f1, fed_with_avg_top_10_ranking as f2
where f1.id = f2.id;
