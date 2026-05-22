with source as (
    select * from {{ source('fpl_data', 'fixtures') }}
),

renamed as (
    select
        id                                                              as fixture_id,
        code,
        event                                                           as gameweek,
        cast(kickoff_time as timestamp)                                 as kickoff_time,
        started,
        finished,
        finished_provisional,
        team_h,
        team_a,
        team_h_score,
        team_a_score,
        team_h_difficulty,
        team_a_difficulty,
        minutes

    from source
)

select * from renamed
