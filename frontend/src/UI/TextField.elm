module UI.TextField exposing (TextField, currentPasswordTextFieldWithValidation, emailTextFieldWithValidation, multilineTextFieldWithValidation, textFieldWithValidation)

import Element exposing (Attribute, Color, Element, column, fill, height, maximum, minimum, px, row, spacing, text, width)
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Html.Events
import Json.Decode as Decode
import UI.ColorPalette exposing (black, red)
import UI.Dimensions exposing (smallScreenWidth)
import UI.Layout exposing (scaled)


type alias TextField msg =
    { title : String
    , initial : String
    , onChange : String -> msg
    , onEnterKey : msg
    , validation : List String
    }


textFieldWithValidation : TextField msg -> Element msg
textFieldWithValidation model =
    withValidation [ textField model ] model.validation


emailTextFieldWithValidation : TextField msg -> Element msg
emailTextFieldWithValidation model =
    withValidation [ emailTextField model ] model.validation


currentPasswordTextFieldWithValidation : TextField msg -> Element msg
currentPasswordTextFieldWithValidation model =
    withValidation [ currentPasswordTextField model ] model.validation


multilineTextFieldWithValidation : TextField msg -> Element msg
multilineTextFieldWithValidation model =
    withValidation [ multilineTextField model ] model.validation


textField : TextField msg -> Element msg
textField model =
    Input.text (textFieldStyle model) (records model)


emailTextField : TextField msg -> Element msg
emailTextField model =
    Input.email (textFieldStyle model) (records model)


currentPasswordTextField : TextField msg -> Element msg
currentPasswordTextField model =
    Input.currentPassword (textFieldStyle model)
        { onChange = model.onChange
        , text = model.initial
        , placeholder = Just (Input.placeholder [] (text model.initial))
        , label = Input.labelAbove [] (text model.title)
        , show = False
        }


multilineTextField : TextField msg -> Element msg
multilineTextField model =
    Input.multiline (multilineTextFieldStyle model) (multilineRecords model)


withValidation : List (Element msg) -> List String -> Element msg
withValidation field validation =
    column [ width fill, spacing 8 ]
        (row [] field :: List.map (\v -> row [ Font.size (scaled -1), Font.color red ] [ text v ]) validation)


textFieldStyle : TextField msg -> List (Attribute msg)
textFieldStyle model =
    [ width fill, Border.color (borderColor (List.length model.validation > 0)), onEnter model.onEnterKey ]


multilineTextFieldStyle : TextField msg -> List (Attribute msg)
multilineTextFieldStyle model =
    [ width
        (fill
            |> maximum (smallScreenWidth // 2)
            |> minimum (smallScreenWidth // 2)
        )
    , height (px 150)
    , Border.color (borderColor (List.length model.validation > 0))
    ]


records : TextField msg -> { label : Input.Label msg, onChange : String -> msg, placeholder : Maybe (Input.Placeholder msg), text : String }
records model =
    { onChange = model.onChange
    , text = model.initial
    , placeholder = Just (Input.placeholder [] (text model.initial))
    , label = Input.labelAbove [] (text model.title)
    }


multilineRecords : TextField msg -> { label : Input.Label msg, onChange : String -> msg, placeholder : Maybe (Input.Placeholder msg), text : String, spellcheck : Bool }
multilineRecords model =
    { onChange = model.onChange
    , text = model.initial
    , placeholder = Just (Input.placeholder [] (text model.initial))
    , label = Input.labelAbove [] (text model.title)
    , spellcheck = True
    }


onEnter : msg -> Attribute msg
onEnter msg =
    Element.htmlAttribute
        (Html.Events.on "keyup"
            (Decode.field "key" Decode.string
                |> Decode.andThen
                    (\key ->
                        if key == "Enter" then
                            Decode.succeed msg

                        else
                            Decode.fail "Not the enter key"
                    )
            )
        )


borderColor : Bool -> Color
borderColor valid =
    if valid then
        red

    else
        black
