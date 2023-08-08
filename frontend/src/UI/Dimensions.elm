module UI.Dimensions exposing (bodyHeight, bodyWidth, defaultPadding, defaultSpacing, fillMaxViewWidth, footerHeightInPx, headerHeightInPx, smallScreenWidth)

import Element exposing (Attribute, Length, fill, maximum, px, width)
import Shared exposing (Window)


maxViewWidth : Int
maxViewWidth =
    1024


fillMaxViewWidth : Attribute msg
fillMaxViewWidth =
    width (maximum maxViewWidth fill)


smallScreenWidth : Int
smallScreenWidth =
    640


defaultPadding : Int
defaultPadding =
    20


defaultSpacing : Int
defaultSpacing =
    20


headerHeight : Int
headerHeight =
    60


headerHeightInPx : Length
headerHeightInPx =
    px headerHeight


footerHeight : Int
footerHeight =
    50


footerHeightInPx : Length
footerHeightInPx =
    px footerHeight


bodyWidth : Window -> Float
bodyWidth window =
    toFloat (min window.width maxViewWidth - 2 * defaultPadding)


bodyHeight : Window -> Float
bodyHeight window =
    toFloat (window.height - 2 * headerHeight - footerHeight - 2 * defaultPadding)
