module UI.Dimensions exposing (fillMaxViewWidth, smallScreenWidth)

import Element exposing (Attribute, fill, maximum, width)


maxViewWidth : Int
maxViewWidth =
    1024


fillMaxViewWidth : Attribute msg
fillMaxViewWidth =
    width (maximum maxViewWidth fill)


smallScreenWidth : Int
smallScreenWidth =
    640
