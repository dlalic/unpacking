module Forms.SnippetForm exposing (EditSnippet, NewSnippet, defaultNew, editForm, editSnippetValidator, newForm, newSnippetValidator, stringFromMedia)

import Api.Data exposing (Media(..), mediaVariants)
import Dict exposing (Dict)
import Element exposing (Element, spacing)
import Forms.Fields exposing (linkField, snippetField)
import Forms.Validators exposing (ValidationField, snippetValidator)
import I18Next exposing (Translations)
import Translations.Buttons exposing (newSnippet)
import Translations.Forms exposing (edit, media, mediaBlog, mediaBook, mediaNews, mediaTwitter, mediaVideo, mediaWebsite)
import UI.Button exposing (tagButton)
import UI.Card exposing (viewForm)
import UI.Checkbox exposing (CheckBox, viewCheckBoxRow)
import Uuid exposing (Uuid)
import Validate exposing (Validator)


type alias NewSnippet =
    { text : String
    , media : Media
    , link : Maybe String
    , authors : Dict String String
    , terms : Dict String String
    , errors : List ( ValidationField, String )
    }


type alias EditSnippet =
    { id : Uuid
    , title : String
    , text : String
    , media : Media
    , link : Maybe String
    , authors : Dict String String
    , terms : Dict String String
    , errors : List ( ValidationField, String )
    }


defaultNew : NewSnippet
defaultNew =
    { text = "", media = MediaBook, link = Nothing, authors = Dict.empty, terms = Dict.empty, errors = [] }


newForm : Translations -> NewSnippet -> Element a -> Element a -> (NewSnippet -> a) -> a -> a -> Element a
newForm translations snippet authorsDropdown termsDropdown onEdit onCancel onSubmit =
    let
        body : List (Element a)
        body =
            [ snippetField translations snippet onEdit onSubmit
            , viewCheckBoxRow (checkBox translations snippet onEdit)
            , linkField translations snippet onEdit onSubmit
            , authorsDropdown
            , Element.row [ spacing 8 ] (List.map (\( id, text ) -> tagButton text (onEdit { snippet | authors = Dict.remove id snippet.authors })) (Dict.toList snippet.authors))
            , termsDropdown
            , Element.row [ spacing 8 ] (List.map (\( id, text ) -> tagButton text (onEdit { snippet | terms = Dict.remove id snippet.terms })) (Dict.toList snippet.terms))
            ]
    in
    viewForm translations (newSnippet translations) body (Just onCancel) onSubmit


editForm : Translations -> EditSnippet -> Element a -> Element a -> (EditSnippet -> a) -> a -> a -> Element a
editForm translations snippet authorsDropdown termsDropdown onEdit onCancel onSubmit =
    let
        body : List (Element a)
        body =
            [ snippetField translations snippet onEdit onSubmit
            , viewCheckBoxRow (checkBox translations snippet onEdit)
            , linkField translations snippet onEdit onSubmit
            , authorsDropdown
            , Element.row [ spacing 8 ] (List.map (\( id, text ) -> tagButton text (onEdit { snippet | authors = Dict.remove id snippet.authors })) (Dict.toList snippet.authors))
            , termsDropdown
            , Element.row [ spacing 8 ] (List.map (\( id, text ) -> tagButton text (onEdit { snippet | terms = Dict.remove id snippet.terms })) (Dict.toList snippet.terms))
            ]
    in
    viewForm translations (edit translations snippet.title) body (Just onCancel) onSubmit


checkBox : Translations -> { a | media : Media } -> ({ a | media : Media } -> msg) -> CheckBox msg
checkBox translations snippet onEdit =
    { title = media translations
    , selected = stringFromMedia translations snippet.media
    , options = List.map (stringFromMedia translations) mediaVariants
    , onChange = \input -> onEdit { snippet | media = mediaFromString translations input }
    }


stringFromMedia : Translations -> Media -> String
stringFromMedia translations model =
    case model of
        MediaBook ->
            mediaBook translations

        MediaBlog ->
            mediaBlog translations

        MediaNews ->
            mediaNews translations

        MediaTwitter ->
            mediaTwitter translations

        MediaVideo ->
            mediaVideo translations

        MediaWebsite ->
            mediaWebsite translations


mediaFromString : Translations -> String -> Media
mediaFromString translations media =
    if mediaBook translations == media then
        MediaBook

    else if mediaBlog translations == media then
        MediaBlog

    else if mediaNews translations == media then
        MediaNews

    else if mediaTwitter translations == media then
        MediaTwitter

    else if mediaVideo translations == media then
        MediaVideo

    else
        MediaWebsite


newSnippetValidator : Translations -> Validator ( ValidationField, String ) NewSnippet
newSnippetValidator translations =
    Validate.all
        [ snippetValidator translations
        ]


editSnippetValidator : Translations -> Validator ( ValidationField, String ) EditSnippet
editSnippetValidator translations =
    Validate.all
        [ snippetValidator translations
        ]
