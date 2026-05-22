with source as (
    select * from {{ source('fpl_data', 'element_summary') }}
),

renamed as (
    select
        element                                                         as player_id,
        fixture                                                         as fixture_id,
        opponent_team,
        round                                                           as gameweek,
        was_home,
        cast(kickoff_time as timestamp)                                 as kickoff_time,
        team_h_score,
        team_a_score,

        -- Performance
        minutes,
        starts,
        total_points,
        goals_scored,
        assists,
        clean_sheets,
        goals_conceded,
        own_goals,
        yellow_cards,
        red_cards,
        saves,
        bonus,
        bps,
        penalties_saved,
        penalties_missed,
        clearances_blocks_interceptions,
        recoveries,
        tackles,
        defensive_contribution,

        -- xG metrics (cast from string)
        cast(expected_goals as float64)                                 as expected_goals,
        cast(expected_assists as float64)                               as expected_assists,
        cast(expected_goal_involvements as float64)                     as expected_goal_involvements,
        cast(expected_goals_conceded as float64)                        as expected_goals_conceded,

        -- ICT metrics (cast from string)
        cast(influence as float64)                                      as influence,
        cast(creativity as float64)                                     as creativity,
        cast(threat as float64)                                         as threat,
        cast(ict_index as float64)                                      as ict_index,

        -- Price at time of gameweek
        round(value / 10.0, 1)                                         as price,
        transfers_balance,
        selected,
        transfers_in,
        transfers_out

    from source
)

select * from renamed
