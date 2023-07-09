module Forms.SignInForm exposing (NewSignIn, defaultNew, newForm, newSignInValidator)

import Element exposing (Element)
import Forms.Fields exposing (currentPasswordField, emailField)
import Forms.Validators exposing (ValidationField, currentPasswordValidator, emailValidator)
import I18Next exposing (Translations)
import Translations.Buttons exposing (signIn)
import UI.Card exposing (viewForm)
import Validate exposing (Validator)


type alias NewSignIn =
    { email : String
    , password : String
    , errors : List ( ValidationField, String )
    }


defaultNew : NewSignIn
defaultNew =
    { email = "", password = "", errors = [] }


newForm : Translations -> NewSignIn -> (NewSignIn -> a) -> a -> Element a
newForm translations user onEdit onSubmit =
    let
        body : List (Element a)
        body =
            [ emailField translations user onEdit onSubmit
            , currentPasswordField translations user onEdit onSubmit
            ]
    in
    viewForm translations (signIn translations) body Nothing onSubmit


newSignInValidator : Translations -> Validator ( ValidationField, String ) NewSignIn
newSignInValidator translations =
    Validate.all
        [ emailValidator translations
        , currentPasswordValidator translations
        ]
