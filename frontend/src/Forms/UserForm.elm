module Forms.UserForm exposing (EditUser, NewUser, defaultNew, editForm, editUserValidator, newForm, newUserValidator, stringFromRole)

import Api.Data exposing (Role(..), roleVariants)
import Element exposing (Element)
import Forms.Fields exposing (emailField, nameField, passwordField)
import Forms.Validators exposing (ValidationField, emailValidator, nameValidator, passwordValidator)
import I18Next exposing (Translations)
import Translations.Buttons exposing (newUser)
import Translations.Forms exposing (edit, role, roleAdmin, roleUser)
import UI.Card exposing (viewForm)
import UI.Checkbox exposing (CheckBox, viewCheckBox)
import Uuid exposing (Uuid)
import Validate exposing (Validator)


type alias NewUser =
    { name : String
    , role : Role
    , email : String
    , password : String
    , errors : List ( ValidationField, String )
    }


type alias EditUser =
    { id : Uuid
    , title : String
    , name : String
    , role : Role
    , email : String
    , errors : List ( ValidationField, String )
    }


defaultNew : NewUser
defaultNew =
    { name = "", email = "", password = "", role = RoleUser, errors = [] }


newForm : Translations -> NewUser -> (NewUser -> a) -> a -> a -> Element a
newForm translations user onEdit onCancel onSubmit =
    let
        body : List (Element a)
        body =
            [ nameField translations user onEdit onSubmit
            , emailField translations user onEdit onSubmit
            , passwordField translations user onEdit onSubmit
            , viewCheckBox (checkBox translations user onEdit)
            ]
    in
    viewForm translations (newUser translations) body (Just onCancel) onSubmit


editForm : Translations -> EditUser -> (EditUser -> a) -> a -> a -> Element a
editForm translations user onEdit onCancel onSubmit =
    let
        body : List (Element a)
        body =
            [ nameField translations user onEdit onSubmit
            , emailField translations user onEdit onSubmit
            , viewCheckBox (checkBox translations user onEdit)
            ]
    in
    viewForm translations (edit translations user.title) body (Just onCancel) onSubmit


checkBox : Translations -> { a | role : Role } -> ({ a | role : Role } -> msg) -> CheckBox msg
checkBox translations user onEdit =
    { title = role translations
    , selected = stringFromRole translations user.role
    , options = List.map (stringFromRole translations) roleVariants
    , onChange = \input -> onEdit { user | role = roleFromString translations input }
    }


stringFromRole : Translations -> Role -> String
stringFromRole translations model =
    case model of
        RoleUser ->
            roleUser translations

        RoleAdmin ->
            roleAdmin translations


roleFromString : Translations -> String -> Role
roleFromString translations role =
    if roleAdmin translations == role then
        RoleAdmin

    else
        RoleUser


newUserValidator : Translations -> Validator ( ValidationField, String ) NewUser
newUserValidator translations =
    Validate.all
        [ nameValidator translations
        , emailValidator translations
        , passwordValidator translations
        ]


editUserValidator : Translations -> Validator ( ValidationField, String ) EditUser
editUserValidator translations =
    Validate.all
        [ nameValidator translations
        , emailValidator translations
        ]
