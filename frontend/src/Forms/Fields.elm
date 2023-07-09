module Forms.Fields exposing (currentPasswordField, emailField, linkField, nameField, passwordField, snippetField)

import Common exposing (errorsForField)
import Element exposing (Element)
import Forms.Validators exposing (ValidationField(..))
import I18Next exposing (Translations)
import Translations.Forms exposing (email, link, name, password, text)
import UI.TextField exposing (currentPasswordTextFieldWithValidation, emailTextFieldWithValidation, multilineTextFieldWithValidation, textFieldWithValidation)


emailField : Translations -> { a | email : String, errors : List ( ValidationField, String ) } -> ({ a | email : String, errors : List ( ValidationField, String ) } -> msg) -> msg -> Element msg
emailField translations user onEdit onSubmit =
    emailTextFieldWithValidation
        { title = email translations
        , initial = user.email
        , onChange = \v -> onEdit { user | email = v }
        , onEnterKey = onSubmit
        , validation = errorsForField Email user.errors
        }


currentPasswordField : Translations -> { a | password : String, errors : List ( ValidationField, String ) } -> ({ a | password : String, errors : List ( ValidationField, String ) } -> msg) -> msg -> Element msg
currentPasswordField translations user onEdit onSubmit =
    currentPasswordTextFieldWithValidation
        { title = password translations
        , initial = user.password
        , onChange = \v -> onEdit { user | password = v }
        , onEnterKey = onSubmit
        , validation = errorsForField Password user.errors
        }


passwordField : Translations -> { a | password : String, errors : List ( ValidationField, String ) } -> ({ a | password : String, errors : List ( ValidationField, String ) } -> msg) -> msg -> Element msg
passwordField translations user onEdit onSubmit =
    textFieldWithValidation
        { title = password translations
        , initial = user.password
        , onChange = \v -> onEdit { user | password = v }
        , onEnterKey = onSubmit
        , validation = errorsForField Password user.errors
        }


nameField : Translations -> { a | name : String, errors : List ( ValidationField, String ) } -> ({ a | name : String, errors : List ( ValidationField, String ) } -> msg) -> msg -> Element msg
nameField translations user onEdit onSubmit =
    textFieldWithValidation
        { title = name translations
        , initial = user.name
        , onChange = \v -> onEdit { user | name = v }
        , onEnterKey = onSubmit
        , validation = errorsForField Name user.errors
        }


snippetField : Translations -> { a | text : String, errors : List ( ValidationField, String ) } -> ({ a | text : String, errors : List ( ValidationField, String ) } -> msg) -> msg -> Element msg
snippetField translations snippet onEdit onSubmit =
    multilineTextFieldWithValidation
        { title = text translations
        , initial = snippet.text
        , onChange = \v -> onEdit { snippet | text = v }
        , onEnterKey = onSubmit
        , validation = errorsForField Text snippet.errors
        }


linkField : Translations -> { a | link : Maybe String, errors : List ( ValidationField, String ) } -> ({ a | link : Maybe String, errors : List ( ValidationField, String ) } -> msg) -> msg -> Element msg
linkField translations snippet onEdit onSubmit =
    textFieldWithValidation
        { title = link translations
        , initial = Maybe.withDefault "" snippet.link
        , onChange = \v -> onEdit { snippet | link = Just v }
        , onEnterKey = onSubmit
        , validation = errorsForField Name snippet.errors
        }
