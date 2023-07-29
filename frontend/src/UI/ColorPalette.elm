module UI.ColorPalette exposing (black, colorFromScale, darkGray, green, lightGray, red, white)

import Color
import Element exposing (Color, rgb255)
import Scale exposing (SequentialScale)
import Scale.Color


white : Color
white =
    rgb255 255 255 255


red : Color
red =
    rgb255 179 28 49


green : Color
green =
    rgb255 42 111 144


black : Color
black =
    rgb255 0 0 0


darkGray : Color
darkGray =
    rgb255 90 90 90


lightGray : Color
lightGray =
    rgb255 120 120 120


colorFromScale : Float -> Color.Color
colorFromScale value =
    let
        colorScale : SequentialScale Color.Color
        colorScale =
            Scale.sequential Scale.Color.viridisInterpolator ( 200, 700 )
    in
    Scale.convert colorScale value
