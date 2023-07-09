module UI.Button exposing (Button, defaultButton, tagButton, viewButton)

import Element exposing (Color, Element, htmlAttribute, mouseOver, moveRight, paddingXY, spacing, text)
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Simple.Transition as Transition
import UI.ColorPalette exposing (darkGray, lightGray, red, white)


type alias Button msg =
    { title : String
    , action : Maybe msg
    , color : Maybe Color
    }


defaultButton : String -> msg -> Element msg
defaultButton title action =
    viewButton { title = title, action = Just action, color = Just darkGray }


viewButton : Button msg -> Element msg
viewButton model =
    Input.button
        [ paddingXY 8 8
        , Border.widthEach
            { bottom = 0
            , left = 2
            , right = 0
            , top = 0
            }
        , Border.color white
        , Font.color (Maybe.withDefault darkGray model.color)
        , Font.size 18
        , properties_
            [ Transition.borderColor 500 []
            , Transition.transform 500 [ Transition.delay 200 ]
            ]
        , mouseOver
            [ Border.color (Maybe.withDefault darkGray model.color)
            , moveRight 2
            ]
        ]
        { onPress = model.action, label = text model.title }


properties_ : List Transition.Property -> Element.Attribute msg
properties_ =
    htmlAttribute << Transition.properties


tagButton : String -> msg -> Element msg
tagButton title action =
    viewTagButton { title = title, action = Just action, color = Just darkGray }


viewTagButton : Button msg -> Element msg
viewTagButton model =
    Input.button
        [ paddingXY 8 8
        , Border.widthEach
            { bottom = 1
            , left = 1
            , right = 1
            , top = 1
            }
        , Border.color lightGray
        , Border.rounded 2
        , Font.color (Maybe.withDefault darkGray model.color)
        , Font.size 18
        ]
        { onPress = model.action, label = Element.row [ spacing 8 ] [ text model.title, Element.el [ Font.color red, Font.bold ] (text "x") ] }
