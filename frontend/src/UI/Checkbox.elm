module UI.Checkbox exposing (CheckBox, viewCheckBox, viewCheckBoxRow)

import Element exposing (Element, centerY, column, el, fill, height, none, padding, paddingXY, px, row, spacing, text, width)
import Element.Background as Background
import Element.Border as Border
import Element.Input as Input exposing (OptionState(..), labelAbove, optionWith, radioRow)
import UI.ColorPalette exposing (black, darkGray, white)


type alias CheckBox msg =
    { title : String
    , selected : String
    , options : List String
    , onChange : String -> msg
    }


viewCheckBox : CheckBox msg -> Element msg
viewCheckBox model =
    column []
        [ radioRow
            [ padding 10
            , spacing 30
            ]
            { onChange = model.onChange
            , selected = Just model.selected
            , label = labelAbove [] (text model.title)
            , options = List.map (\v -> optionWith v (radioOption v)) model.options
            }
        ]


viewCheckBoxRow : CheckBox msg -> Element msg
viewCheckBoxRow model =
    column []
        [ Input.radio
            [ paddingXY 0 20
            , spacing 10
            ]
            { onChange = model.onChange
            , selected = Just model.selected
            , label = labelAbove [] (text model.title)
            , options = List.map (\v -> optionWith v (radioOption v)) model.options
            }
        ]


radioOption : String -> OptionState -> Element msg
radioOption label state =
    row [ spacing 10 ]
        [ el
            [ width (px 24)
            , height (px 24)
            , centerY
            , padding 4
            , Border.rounded 12
            , Border.width 1
            , Border.color darkGray
            ]
            (el
                [ width fill
                , height fill
                , Border.rounded 12
                , Background.color
                    (case state of
                        Idle ->
                            white

                        Focused ->
                            darkGray

                        Selected ->
                            black
                    )
                ]
                none
            )
        , text label
        ]
