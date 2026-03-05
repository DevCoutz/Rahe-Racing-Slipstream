SlipstreamConfig = {
    -------------------------------------------------
    -- DETECTION (Slipstream cone settings)
    -------------------------------------------------

    -- Maximum distance (in meters) to consider being in another car's slipstream.
    -- Higher values make it easier to catch the draft. GTA Online uses ~20-25m.
    maxDistance = 22.0,

    -- Minimum distance to prevent applying boost when too close to the car ahead.
    minDistance = 3.0,

    -- Maximum angle (in degrees) of the detection cone behind the leading vehicle.
    -- 20 = narrow cone (must be well aligned), 40 = wide cone (easier to draft).
    coneAngle = 25.0,

    -------------------------------------------------
    -- BOOST (Slipstream force settings)
    -------------------------------------------------

    -- Base boost force applied per tick while in the slipstream.
    -- Values between 0.2 and 0.6 are recommended. Above 1.0 feels very arcade.
    boostForce = 0.35,

    -- Maximum boost force (when the slipstream is fully charged).
    -- The boost starts weak and grows as you stay in the draft.
    maxBoostForce = 0.55,

    -- Time (in seconds) required in the slipstream to reach maximum boost.
    -- Simulates the "charge up" effect similar to GTA Online.
    chargeTime = 2.5,

    -- Time (in seconds) the residual boost lasts after leaving the slipstream.
    -- Allows the player to use accumulated momentum for overtaking.
    residualDuration = 1.2,

    -- Percentage of boost retained as residual (0.0 to 1.0).
    residualMultiplier = 0.6,

    -- Minimum vehicle speed (in km/h) for slipstream to activate.
    -- Prevents the effect from working at low speeds where it doesn't make aerodynamic sense.
    minSpeed = 60.0,

    -------------------------------------------------
    -- VISUALS AND EFFECTS
    -------------------------------------------------

    -- Enable screen effect when drafting.
    enableVisualEffect = true,

    -- Screen effect intensity while in the slipstream.
    -- 0.0 = disabled, 1.0 = maximum. Recommended: 0.3 to 0.5
    screenEffectIntensity = 0.3,

    -- Enable HUD indicator showing the slipstream charge level.
    enableHUD = true,

    -- HUD indicator position (0.0 to 1.0, where 0.0 = left/top, 1.0 = right/bottom).
    hudX = 0.5,
    hudY = 0.88,

    -- HUD indicator colors (R, G, B, A).
    hudColorEmpty = { r = 255, g = 255, b = 255, a = 100 },
    hudColorFull  = { r = 0,   g = 200, b = 255, a = 220 },

    -- Enable sound feedback when the slipstream activates.
    enableSound = true,

    -------------------------------------------------
    -- PERFORMANCE
    -------------------------------------------------

    -- Main tick interval in milliseconds.
    -- Lower = more precise but heavier. 0 = every frame.
    tickInterval = 0,

    -- Server sync interval (ms).
    -- The server needs to know who is in a race. Doesn't need to be very fast.
    syncInterval = 2000,

    -------------------------------------------------
    -- DEBUG
    -------------------------------------------------

    -- Enable debug mode (shows lines, distances and angles on screen).
    debug = false,
}
