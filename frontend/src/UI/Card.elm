module UI.Card exposing (Card, keyedCard, viewForm)

import Element exposing (Attribute, Element, alignLeft, alignRight, column, el, fill, height, padding, paragraph, row, spacing, text, width)
import Element.Background as Background
import Element.Border as Border
import Element.Events exposing (onClick)
import Element.Font as Font
import Element.Keyed as Keyed
import I18Next exposing (Translations)
import Translations.Buttons exposing (cancel, submit)
import UI.Button exposing (defaultButton)
import UI.ColorPalette exposing (black, lightGray, red, white)
import UI.Dimensions exposing (defaultPadding, defaultSpacing)
import Uuid exposing (Uuid)


type alias Card msg =
    { title : String
    , rightLabel : String
    , body : List (Element msg)
    , onClick : Maybe msg
    , buttons : List (Element msg)
    }


viewForm : Translations -> String -> List (Element msg) -> Maybe msg -> msg -> Element msg
viewForm translations title body onCancel onSubmit =
    let
        buttons : List (Element msg)
        buttons =
            case onCancel of
                Just some ->
                    [ defaultButton (cancel translations) some, defaultButton (submit translations) onSubmit ]

                _ ->
                    [ defaultButton (submit translations) onSubmit ]
    in
    column cardStyle (rows { title = title, rightLabel = "", body = body, onClick = Nothing, buttons = buttons })


keyedCard : Card msg -> Uuid -> Element msg
keyedCard model id =
    Keyed.column cardStyle (List.map (\v -> ( Uuid.toString id, v )) (rows model))


rows : Card msg -> List (Element msg)
rows model =
    let
        style : List (Attribute msg)
        style =
            case model.onClick of
                Just some ->
                    [ width fill, onClick some ]

                Nothing ->
                    [ width fill ]
    in
    row style
        [ el [ alignLeft, Font.bold, width fill ] (paragraph [ width fill ] [ text model.title ])
        , el [ alignRight, Font.color red, height fill ] (text model.rightLabel)
        ]
        :: List.map (\v -> row style [ v ]) model.body
        ++ [ row [ spacing 16 ] model.buttons ]


cardStyle : List (Attribute msg)
cardStyle =
    [ Background.color white
    , Font.color black
    , Border.widthEach
        { bottom = 1
        , left = 0
        , right = 0
        , top = 0
        }
    , Border.color lightGray
    , padding defaultPadding
    , spacing defaultSpacing
    , width fill
    ]
