module UI.Dialog exposing (Dialog, defaultDialog)

import Dialog exposing (Config)
import Element exposing (Element, centerX, centerY, padding, row, spacing, text)
import Element.Background as Background
import I18Next exposing (Translations)
import Translations.Buttons exposing (cancel, confirm)
import Translations.Dialogs exposing (confirmTitle)
import UI.Button exposing (defaultButton, viewButton)
import UI.ColorPalette exposing (red, white)


type alias Dialog msg =
    { title : String
    , cancelTitle : String
    , confirmTitle : String
    , onCancel : msg
    , onConfirm : msg
    }


defaultDialog : Translations -> msg -> msg -> Element msg
defaultDialog translations onCancel onConfirm =
    viewDialog
        { title = confirmTitle translations
        , cancelTitle = cancel translations
        , confirmTitle = confirm translations
        , onCancel = onCancel
        , onConfirm = onConfirm
        }


viewDialog : Dialog msg -> Element msg
viewDialog model =
    let
        config : Config msg
        config =
            { closeMessage = Nothing
            , maskAttributes = [ Background.color white ]
            , headerAttributes = []
            , bodyAttributes = []
            , footerAttributes = []
            , containerAttributes =
                [ Background.color white
                , centerX
                , centerY
                , padding 24
                , spacing 16
                ]
            , header = Just (text model.title)
            , body = Just (body model)
            , footer = Nothing
            }
    in
    Dialog.view (Just config)


body : Dialog msg -> Element msg
body model =
    row [ spacing 16 ]
        [ defaultButton model.cancelTitle model.onCancel
        , viewButton { title = model.confirmTitle, action = Just model.onConfirm, color = Just red }
        ]
