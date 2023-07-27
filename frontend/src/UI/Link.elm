module UI.Link exposing (defaultLink, footerLink)

import Element exposing (Color, Element, newTabLink, text)
import Element.Font as Font
import UI.ColorPalette exposing (green)


type alias Link =
    { title : String
    , url : String
    , size : Int
    , color : Maybe Color
    }


defaultLink : String -> String -> Element msg
defaultLink title url =
    viewLink { title = title, url = url, size = 18, color = Nothing }


footerLink : String -> String -> Element msg
footerLink title url =
    viewLink { title = title, url = url, size = 12, color = Nothing }


viewLink : Link -> Element msg
viewLink model =
    newTabLink
        [ Font.color (Maybe.withDefault green model.color)
        , Font.size model.size
        , Font.bold
        , Font.underline
        ]
        { url = model.url, label = text model.title }
