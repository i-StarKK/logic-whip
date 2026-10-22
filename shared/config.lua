--[[
    logic-whip - config
    Author: StarK (Moayed)
    Team: logic
    https://github.com/i-StarKK/logic-whip
]]

WhipConfig = {
    command = 'whip',
    ace = false,
    syncDistance = 60.0,
    checkUpdates = true,

    models = {
        handle = 'logic_whip',
        popper = 'logic_whip_popper',
        lash = {
            'logic_whip_lash1',
            'logic_whip_lash1',
            'logic_whip_lash1',
            'logic_whip_lash1',
            'logic_whip_lash2',
            'logic_whip_lash2',
            'logic_whip_lash2',
            'logic_whip_lash2',
            'logic_whip_lash3',
            'logic_whip_lash3',
            'logic_whip_lash3',
            'logic_whip_lash4',
            'logic_whip_lash4',
            'logic_whip_lash4',
        },
    },

    lash = {
        tip = 0.32,
        pitch = 0.14,
        gravity = 9.81,
        damping = 0.95,
        iterations = 6,
        stiffness = 0.25,
        sleepFrames = 30,
        wakeDistance = 0.25,
    },

    attach = {
        bone = 57005,
        offset = vector3(0.09, 0.03, 0.02),
        rotation = vector3(80.0, 0.0, 0.0),
    },

    hold = { dict = 'move_weapon@jerrycan@generic', clip = 'idle', flag = 49 },

    swing = {
        dict = 'melee@small_wpn@streamed_core',
        clip = 'small_melee_wpn_short_range_0',
        flag = 48,
        hitMs = 380,
        durationMs = 900,
        cooldownMs = 950,
    },

    hit = {
        reach = 2.8,
        damage = 0,
        bloodPack = 'SCR_Torture',
        bloodPerHit = 0.12,
        shake = 0.12,
        reactions = {
            front = { dict = 'melee@unarmed@streamed_core', clip = 'non_melee_damage_front' },
            back = { dict = 'melee@unarmed@streamed_core', clip = 'melee_damage_back' },
            left = { dict = 'melee@unarmed@streamed_core', clip = 'melee_damage_left' },
            right = { dict = 'melee@unarmed@streamed_core', clip = 'melee_damage_right' },
        },
    },

    sounds = {
        volume = 0.9,
        maxDistance = 60.0,
        rolloff = 1.3,
        crack = { count = 3, volume = 1.0, ref = 4.0 },
        hit = { count = 3, volume = 1.0, ref = 3.0 },
    },

    text = {
        on = 'Whip in hand. Left click to crack it.',
        off = 'Whip put away.',
        denied = 'You are not allowed to use the whip.',
    },
}
