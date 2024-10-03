module Pages.Snippets exposing (Model, Msg, State, page)

import Api
import Api.Data exposing (AuthorResponse, Media(..), Role(..), SnippetResponse, SnippetSearchResponse, TermResponse, UpdateSnippet)
import Api.Request.Default exposing (deleteSnippets, readAllAuthors, readAllTerms, searchSnippets, updateSnippets)
import Auth
import Common exposing (uuidFromString)
import Dict
import Element exposing (Color, Element, height, image, paragraph, px, row, spacing, text, width)
import Element.Font as Font
import Embed.Youtube
import Embed.Youtube.Thumbnail as Thumb
import Forms.SnippetForm exposing (EditSnippet, editForm, editSnippetValidator, stringFromMedia)
import Forms.Validators exposing (ValidationField)
import Gen.Route as Route
import Http
import Page
import Problem exposing (isUnauthenticated)
import Request exposing (Request)
import SearchBox exposing (ChangeEvent(..))
import Set exposing (Set)
import Shared
import Storage exposing (Storage)
import Translations.Buttons exposing (delete, edit, newSnippet, source)
import Translations.Forms as Forms
import Translations.Labels exposing (loading, onError, videoThumbnail)
import Translations.Titles exposing (snippets)
import UI.Button exposing (defaultButton, tagButton, viewButton)
import UI.Card exposing (keyedCard)
import UI.ColorPalette exposing (darkGray, green)
import UI.Dialog exposing (defaultDialog)
import UI.Dropdown exposing (Dropdown, dropdown, initModel, updateModel)
import UI.Layout as Layout
import UI.Link exposing (defaultLink)
import Url
import Uuid exposing (Uuid)
import Validate exposing (Valid, fromValid, validate)
import View exposing (View)


page : Shared.Model -> Request -> Page.With Model Msg
page shared req =
    Page.protected.element
        (\session ->
            { init = init session req
            , update = update req shared.storage
            , view = view shared
            , subscriptions = \_ -> Sub.none
            }
        )


type alias Model =
    { session : Auth.User
    , state : State
    , toUpdate : Maybe EditSnippet
    , toDelete : Maybe Uuid
    , terms : Maybe (List TermResponse)
    , authors : Maybe (List AuthorResponse)
    , authorsDropdown : Dropdown
    , termsDropdown : Dropdown
    , currentPage : Int
    , term : Maybe ( Uuid, String )
    }


type State
    = Loading
    | Loaded SnippetSearchResponse
    | LoadedEdit ( List TermResponse, List AuthorResponse )
    | Errored String


init : Auth.User -> Request -> ( Model, Cmd Msg )
init session req =
    loadSnippets
        { session = session
        , state = Loading
        , toUpdate = Nothing
        , toDelete = Nothing
        , authors = Nothing
        , terms = Nothing
        , authorsDropdown = initModel
        , termsDropdown = initModel
        , currentPage = 1
        , term = Maybe.map2 (\a b -> ( a, b )) (Maybe.andThen (\v -> Uuid.fromString v) (Dict.get "termID" req.query)) (Dict.get "name" req.query)
        }


type Msg
    = SnippetsLoaded (Result Http.Error SnippetSearchResponse)
    | SnippetDeleted (Result Http.Error ())
    | SnippetUpdated (Result Http.Error ())
    | ClickedNew
    | Edit EditSnippet
    | TermsLoaded (Result Http.Error (List TermResponse))
    | AuthorsLoaded (Result Http.Error (List AuthorResponse))
    | ChangedAuthorsDropdown (ChangeEvent AuthorResponse)
    | ChangedTermsDropdown (ChangeEvent TermResponse)
    | ClickedCancelEdit
    | ClickedSubmitEdit (Result (List ( ValidationField, String )) (Valid EditSnippet))
    | ClickedDelete Uuid
    | ClickedCancelDelete
    | ClickedSubmitDelete
    | ClickedPage Int
    | ClickedClearTerm


update : Request -> Storage -> Msg -> Model -> ( Model, Cmd Msg )
update req storage msg model =
    case msg of
        SnippetsLoaded (Ok result) ->
            ( { model | state = Loaded result }, Request.pushRoute Route.Snippets req )

        SnippetsLoaded (Err err) ->
            if isUnauthenticated err then
                ( model, Storage.signOut storage )

            else
                ( { model | state = Errored (Problem.toString err) }, Cmd.none )

        ClickedNew ->
            ( model, Request.pushRoute Route.Snippets__New req )

        Edit snippet ->
            ( { model | toUpdate = Just snippet }, Cmd.batch [ Api.send TermsLoaded (readAllTerms model.session.token), Api.send AuthorsLoaded (readAllAuthors model.session.token) ] )

        TermsLoaded (Ok list) ->
            case model.authors of
                Just b ->
                    ( { model | state = LoadedEdit ( list, b ) }, Cmd.none )

                _ ->
                    ( { model | terms = Just list }, Cmd.none )

        TermsLoaded (Err err) ->
            if isUnauthenticated err then
                ( model, Storage.signOut storage )

            else
                ( { model | state = Errored (Problem.toString err) }, Cmd.none )

        AuthorsLoaded (Ok list) ->
            case model.terms of
                Just a ->
                    ( { model | state = LoadedEdit ( a, list ) }, Cmd.none )

                _ ->
                    ( { model | authors = Just list }, Cmd.none )

        AuthorsLoaded (Err err) ->
            if isUnauthenticated err then
                ( model, Storage.signOut storage )

            else
                ( { model | state = Errored (Problem.toString err) }, Cmd.none )

        ChangedAuthorsDropdown changeEvent ->
            case ( model.toUpdate, changeEvent ) of
                ( Just toUpdate, SelectionChanged sth ) ->
                    ( { model | authorsDropdown = updateModel changeEvent model.authorsDropdown, toUpdate = Just { toUpdate | authors = Dict.insert (Uuid.toString sth.id) sth.name toUpdate.authors } }, Cmd.none )

                _ ->
                    ( { model | authorsDropdown = updateModel changeEvent model.authorsDropdown }, Cmd.none )

        ChangedTermsDropdown changeEvent ->
            case ( model.toUpdate, changeEvent ) of
                ( Just toUpdate, SelectionChanged sth ) ->
                    ( { model | termsDropdown = updateModel changeEvent model.termsDropdown, toUpdate = Just { toUpdate | terms = Dict.insert (Uuid.toString sth.id) sth.name toUpdate.terms } }, Cmd.none )

                _ ->
                    ( { model | termsDropdown = updateModel changeEvent model.termsDropdown }, Cmd.none )

        ClickedCancelEdit ->
            loadSnippets model

        ClickedSubmitEdit (Ok input) ->
            let
                valid : EditSnippet
                valid =
                    fromValid input

                new : Set String
                new =
                    Set.fromList (String.split "," model.authorsDropdown.text)

                existing : Set String
                existing =
                    Set.fromList (Dict.values valid.authors)

                diff : Set String
                diff =
                    Set.diff new existing

                updatedSnippet : UpdateSnippet
                updatedSnippet =
                    { text = valid.text
                    , media = valid.media
                    , link = valid.link
                    , existingAuthors = List.concatMap uuidFromString (Dict.keys valid.authors)
                    , newAuthors = List.filter (\v -> String.length v > 0) (Set.toList diff)
                    , terms = List.concatMap uuidFromString (Dict.keys valid.terms)
                    }
            in
            updateSnippet model valid.id updatedSnippet

        ClickedSubmitEdit (Err list) ->
            case model.toUpdate of
                Just some ->
                    ( { model | toUpdate = Just { some | errors = list } }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        SnippetUpdated (Ok _) ->
            loadSnippets model

        SnippetUpdated (Err err) ->
            if isUnauthenticated err then
                ( model, Storage.signOut storage )

            else
                ( { model | state = Errored (Problem.toString err) }, Cmd.none )

        ClickedDelete uuid ->
            ( { model | toDelete = Just uuid }, Cmd.none )

        ClickedCancelDelete ->
            ( { model | toDelete = Nothing }, Cmd.none )

        ClickedSubmitDelete ->
            case model.toDelete of
                Just uuid ->
                    deleteSnippet model uuid

                Nothing ->
                    ( model, Cmd.none )

        SnippetDeleted (Ok _) ->
            loadSnippets model

        SnippetDeleted (Err err) ->
            if isUnauthenticated err then
                ( model, Storage.signOut storage )

            else
                ( { model | state = Errored (Problem.toString err) }, Cmd.none )

        ClickedPage i ->
            loadSnippets { model | currentPage = i }

        ClickedClearTerm ->
            loadSnippets { model | term = Nothing }


view : Shared.Model -> Model -> View Msg
view shared model =
    { title = snippets shared.translations
    , body = Layout.layout Route.Snippets shared (viewSnippets shared model)
    }


viewSnippets : Shared.Model -> Model -> List (Element Msg)
viewSnippets shared model =
    case model.state of
        Loading ->
            [ text (loading shared.translations) ]

        Loaded response ->
            let
                termButton : Element Msg
                termButton =
                    case model.term of
                        Just ( _, name ) ->
                            tagButton name ClickedClearTerm

                        Nothing ->
                            Element.none

                common : List (Element Msg)
                common =
                    List.map (viewSnippet shared (model.session.role == RoleAdmin)) response.snippets
                        ++ [ viewPagination model.currentPage response.pages ]
            in
            case ( model.session.role, model.toUpdate, model.toDelete ) of
                ( RoleAdmin, _, Just _ ) ->
                    [ defaultDialog shared.translations ClickedCancelDelete ClickedSubmitDelete ]

                ( RoleAdmin, _, _ ) ->
                    termButton :: defaultButton (newSnippet shared.translations) ClickedNew :: common

                ( RoleUser, _, _ ) ->
                    termButton :: common

        LoadedEdit ( terms, authors ) ->
            case ( model.session.role, model.toUpdate ) of
                ( RoleAdmin, Just toUpdate ) ->
                    [ editSnippet shared toUpdate model authors terms ]

                _ ->
                    []

        Errored reason ->
            [ text (onError shared.translations reason) ]


viewSnippet : Shared.Model -> Bool -> SnippetResponse -> Element Msg
viewSnippet shared canEdit snippet =
    let
        authors : String
        authors =
            String.join ", " (List.map (\v -> v.name) snippet.authors)

        link : List (Element msg)
        link =
            case snippet.link of
                Just a ->
                    [ defaultLink (source shared.translations) a ]

                Nothing ->
                    []

        video : List (Element msg)
        video =
            case ( snippet.link, snippet.media ) of
                ( Just v, MediaVideo ) ->
                    case Maybe.andThen Embed.Youtube.fromUrl (Url.fromString v) of
                        Just a ->
                            [ image [ width (px 320), height (px 180) ] { src = Url.toString (Thumb.toUrl Thumb.MediumQuality a), description = videoThumbnail shared.translations } ]

                        Nothing ->
                            []

                _ ->
                    []

        body : List (Element msg)
        body =
            paragraph [ Font.family [ Font.typeface "Redaction", Font.serif ], Font.size 18 ] [ text snippet.text ]
                :: video
                ++ link
                ++ [ paragraph [ Font.size 16 ] [ text (String.join ", " (List.map (\v -> v.name) snippet.terms)) ] ]

        buttons : List (Element Msg)
        buttons =
            if canEdit then
                [ defaultButton (edit shared.translations) (Edit (editSnippetFromSnippet snippet))
                , defaultButton (delete shared.translations) (ClickedDelete snippet.id)
                ]

            else
                []
    in
    keyedCard { title = authors, rightLabel = stringFromMedia shared.translations snippet.media, body = body, onClick = Nothing, buttons = buttons } snippet.id


viewPagination : Int -> Int -> Element Msg
viewPagination currentPage pages =
    let
        pageButton : Int -> Element Msg
        pageButton i =
            let
                color : Color
                color =
                    if i == currentPage then
                        green

                    else
                        darkGray
            in
            viewButton { title = String.fromInt i, action = Just (ClickedPage i), color = Just color }
    in
    if pages > 0 then
        row [ spacing 10 ] (defaultButton " « " (ClickedPage 1) :: List.map (\v -> pageButton v) (List.range 1 pages) ++ [ defaultButton " » " (ClickedPage pages) ])

    else
        Element.none


editSnippet : Shared.Model -> EditSnippet -> Model -> List AuthorResponse -> List TermResponse -> Element Msg
editSnippet shared snippet model authors terms =
    let
        submit : Msg
        submit =
            ClickedSubmitEdit (validate (editSnippetValidator shared.translations) snippet)

        aDropdown : Element Msg
        aDropdown =
            dropdown (Forms.authors shared.translations) model.authorsDropdown authors ChangedAuthorsDropdown []

        tDropdown : Element Msg
        tDropdown =
            dropdown (Forms.terms shared.translations) model.termsDropdown terms ChangedTermsDropdown []
    in
    editForm shared.translations snippet aDropdown tDropdown Edit ClickedCancelEdit submit


deleteSnippet : Model -> Uuid -> ( Model, Cmd Msg )
deleteSnippet model uuid =
    ( { model | state = Loading, toDelete = Nothing }, Api.send SnippetDeleted (deleteSnippets uuid model.session.token) )


updateSnippet : Model -> Uuid -> UpdateSnippet -> ( Model, Cmd Msg )
updateSnippet model id snippet =
    ( { model | state = Loading, toUpdate = Nothing, authors = Nothing, terms = Nothing, authorsDropdown = initModel, termsDropdown = initModel }
    , Api.send SnippetUpdated (updateSnippets id snippet model.session.token)
    )


loadSnippets : Model -> ( Model, Cmd Msg )
loadSnippets model =
    ( { model | state = Loading }, Api.send SnippetsLoaded (searchSnippets model.currentPage (Maybe.map (\( v, _ ) -> v) model.term) model.session.token) )


editSnippetFromSnippet : SnippetResponse -> EditSnippet
editSnippetFromSnippet model =
    let
        cutOff : Int
        cutOff =
            32

        title : String
        title =
            String.left cutOff model.text
                ++ (if String.length model.text > cutOff then
                        "..."

                    else
                        ""
                   )
    in
    { id = model.id
    , title = title
    , text = model.text
    , media = model.media
    , link = model.link
    , authors = List.foldl (\v dict -> Dict.insert (Uuid.toString v.id) v.name dict) Dict.empty model.authors
    , terms = List.foldl (\v dict -> Dict.insert (Uuid.toString v.id) v.name dict) Dict.empty model.terms
    , errors = []
    }
