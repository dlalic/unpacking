module Forms.TermForm exposing (EditTerm, NewTerm, defaultNew, editForm, editTermValidator, newForm, newTermValidator)

import Dict exposing (Dict)
import Element exposing (Element, spacing)
import Forms.Fields exposing (nameField)
import Forms.Validators exposing (ValidationField, nameValidator)
import I18Next exposing (Translations)
import Translations.Buttons exposing (newTerm)
import Translations.Forms exposing (edit)
import UI.Button exposing (tagButton)
import UI.Card exposing (viewForm)
import Uuid exposing (Uuid)
import Validate exposing (Validator)


type alias NewTerm =
    { name : String
    , related : Dict String String
    , errors : List ( ValidationField, String )
    }


type alias EditTerm =
    { id : Uuid
    , title : String
    , name : String
    , related : Dict String String
    , errors : List ( ValidationField, String )
    }


defaultNew : NewTerm
defaultNew =
    { name = "", related = Dict.empty, errors = [] }


newForm : Translations -> NewTerm -> Element a -> (NewTerm -> a) -> a -> a -> Element a
newForm translations term dropdown onEdit onCancel onSubmit =
    let
        body : List (Element a)
        body =
            [ nameField translations term onEdit onSubmit
            , dropdown
            , Element.row [ spacing 8 ] (List.map (\( id, text ) -> tagButton text (onEdit { term | related = Dict.remove id term.related })) (Dict.toList term.related))
            ]
    in
    viewForm translations (newTerm translations) body (Just onCancel) onSubmit


editForm : Translations -> EditTerm -> Element a -> (EditTerm -> a) -> a -> a -> Element a
editForm translations term dropdown onEdit onCancel onSubmit =
    let
        body : List (Element a)
        body =
            [ nameField translations term onEdit onSubmit
            , dropdown
            , Element.row [ spacing 8 ] (List.map (\( id, text ) -> tagButton text (onEdit { term | related = Dict.remove id term.related })) (Dict.toList term.related))
            ]
    in
    viewForm translations (edit translations term.title) body (Just onCancel) onSubmit


newTermValidator : Translations -> Validator ( ValidationField, String ) NewTerm
newTermValidator translations =
    Validate.all
        [ nameValidator translations
        ]


editTermValidator : Translations -> Validator ( ValidationField, String ) EditTerm
editTermValidator translations =
    Validate.all
        [ nameValidator translations
        ]
