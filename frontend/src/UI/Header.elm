module UI.Header exposing (HeaderButton, Home, header)

import Element exposing (Element, alignRight, fill, height, link, padding, row, text, width)
import Element.Border as Border
import Element.Font as Font
import Route.Path
import UI.ColorPalette exposing (darkGray)
import UI.Dimensions exposing (defaultPadding, headerHeightInPx)


type alias Home =
    { title : String
    , route : Route.Path.Path
    }


type alias HeaderButton =
    { title : String
    , route : Route.Path.Path
    }


homeLink : Route.Path.Path -> String -> Element msg
homeLink route title =
    link [ Font.bold ] { url = Route.Path.toString route, label = text title }


buttonLink : Route.Path.Path -> String -> Element msg
buttonLink route title =
    link [ alignRight, Font.size 18, Font.color darkGray ] { url = Route.Path.toString route, label = text title }


header : Home -> Maybe HeaderButton -> Element msg
header home button =
    let
        link : List (Element msg)
        link =
            case button of
                Just a ->
                    [ buttonLink a.route a.title ]

                Nothing ->
                    []
    in
    row [ width fill, padding defaultPadding, height headerHeightInPx, Border.widthEach { left = 0, top = 0, right = 0, bottom = 1 } ]
        (List.append [ homeLink home.route home.title ] link)
