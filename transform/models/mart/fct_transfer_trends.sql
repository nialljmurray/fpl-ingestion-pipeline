with players as (
    select * from {{ ref('stg_players') }}
),

teams as (
    select * from {{ ref('stg_teams') }}
)

select
    p.player_id,
    p.web_name,
    p.first_name,
    p.second_name,
    p.position,
    t.name                                                              as team_name,
    t.short_name                                                        as team_short_name,
    p.price,
    p.selected_by_percent,
    p.form,
    p.total_points,
    p.points_per_game,
    p.status,

    -- This gameweek transfers
    p.transfers_in_event,
    p.transfers_out_event,
    p.transfers_in_event - p.transfers_out_event                      as net_transfers_event,

    -- Season transfers
    p.transfers_in,
    p.transfers_out,
    p.transfers_in - p.transfers_out                                  as net_transfers_season,

    -- Price movement
    p.cost_change_start,
    p.cost_change_event,

    -- Value
    p.points_per_million,
    p.points_per_90,

    case
        when p.transfers_in_event > p.transfers_out_event * 2 then 'Strong Buy'
        when p.transfers_in_event > p.transfers_out_event     then 'Buy'
        when p.transfers_out_event > p.transfers_in_event * 2 then 'Strong Sell'
        when p.transfers_out_event > p.transfers_in_event     then 'Sell'
        else 'Neutral'
    end                                                                 as transfer_momentum

from players p
left join teams t on p.team = t.team_id

where p.minutes > 0

order by net_transfers_event desc
