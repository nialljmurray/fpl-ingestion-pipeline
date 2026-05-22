with element_summary as (
    select * from {{ ref('stg_element_summary') }}
),

players as (
    select * from {{ ref('stg_players') }}
),

teams as (
    select * from {{ ref('stg_teams') }}
)

select
    es.gameweek,
    es.player_id,
    p.web_name,
    p.first_name,
    p.second_name,
    p.position,
    p.position_id,
    t.name                                                              as team_name,
    t.short_name                                                        as team_short_name,
    opp.name                                                            as opponent_name,
    opp.short_name                                                      as opponent_short_name,
    es.was_home,
    es.kickoff_time,
    es.fixture_id,

    -- Performance
    es.minutes,
    es.starts,
    es.total_points,
    es.goals_scored,
    es.assists,
    es.clean_sheets,
    es.goals_conceded,
    es.own_goals,
    es.yellow_cards,
    es.red_cards,
    es.saves,
    es.bonus,
    es.bps,
    es.penalties_saved,
    es.penalties_missed,
    es.clearances_blocks_interceptions,
    es.recoveries,
    es.tackles,
    es.defensive_contribution,

    -- xG
    es.expected_goals,
    es.expected_assists,
    es.expected_goal_involvements,
    es.expected_goals_conceded,

    -- ICT
    es.influence,
    es.creativity,
    es.threat,
    es.ict_index,

    -- Cost and selection at time of gameweek
    es.price,
    es.selected,
    es.transfers_in,
    es.transfers_out,
    es.transfers_balance

from element_summary es
left join players p on es.player_id = p.player_id
left join teams t on p.team = t.team_id
left join teams opp on es.opponent_team = opp.team_id
