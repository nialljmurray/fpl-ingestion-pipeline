with source as (
    select * from {{ source('fpl_data', 'teams') }}
),

renamed as (
    select
        id                                                              as team_id,
        name,
        short_name,
        code,
        position                                                        as league_position,
        played,
        win,
        draw,
        loss,
        points                                                          as league_points,
        strength,
        strength_overall_home,
        strength_overall_away,
        strength_attack_home,
        strength_attack_away,
        strength_defence_home,
        strength_defence_away,
        cast(form as float64)                                           as form,
        unavailable

    from source
)

select * from renamed
