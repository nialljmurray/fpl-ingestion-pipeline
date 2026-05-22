with players as (
    select * from {{ ref('stg_players') }}
),

player_form as (
    select * from {{ ref('fct_player_form') }}
),

next_fixtures as (
    select * from {{ ref('fct_fixture_schedule') }}
    where gameweek = (
        select min(gameweek) from {{ ref('fct_fixture_schedule') }}
    )
),

player_next_fixture as (
    select
        p.player_id,
        p.web_name,
        p.position,
        p.price,
        p.selected_by_percent,
        p.form,
        p.total_points,
        p.points_per_game,
        p.minutes,
        pf.points_last_5_gw,
        pf.avg_points_last_5_gw,
        pf.xgi_last_5_gw,
        nf.gameweek                                                     as next_gameweek,
        nf.opponent_short_name,
        nf.venue,
        nf.difficulty                                                   as fixture_difficulty,
        nf.difficulty_label

    from players p
    left join player_form pf on p.player_id = pf.player_id
    left join next_fixtures nf on p.team = nf.team_id

    where p.minutes > 450
      and p.status = 'a'
),

scored as (
    select
        *,
        round(
            (coalesce(avg_points_last_5_gw, 0) * 0.4)
            + (coalesce(xgi_last_5_gw, 0) * 3.0)
            + (case
                when fixture_difficulty <= 2 then 5.0
                when fixture_difficulty = 3  then 3.0
                else 0.0
               end)
            + (coalesce(form, 0) * 0.5),
            2
        )                                                               as captain_score
    from player_next_fixture
)

select
    player_id,
    web_name,
    position,
    price,
    selected_by_percent,
    form,
    points_last_5_gw,
    round(avg_points_last_5_gw, 2)                                     as avg_points_last_5_gw,
    round(xgi_last_5_gw, 2)                                            as xgi_last_5_gw,
    total_points,
    points_per_game,
    next_gameweek,
    opponent_short_name,
    venue,
    fixture_difficulty,
    difficulty_label,
    captain_score

from scored
order by captain_score desc
limit 20
