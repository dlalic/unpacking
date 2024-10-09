module Pages.Terms exposing (Model, Msg, State, page)

import Api
import Api.Data exposing (Role(..), TermResponse, UpdateTerm)
import Api.Request.Default exposing (deleteTerms, readAllTerms, updateTerms)
import Auth
import Common exposing (uuidFromString)
import Dict
import Effect exposing (Effect)
import Element exposing (Element, paragraph, text)
import Element.Font as Font
import Forms.TermForm exposing (EditTerm, editForm, editTermValidator)
import Forms.Validators exposing (ValidationField)
import Http
import Layouts
import Page exposing (Page)
import Problem exposing (isUnauthenticated)
import Route exposing (Route)
import Route.Path
import SearchBox exposing (ChangeEvent(..))
import Shared
import Translations.Buttons exposing (delete, edit, newTerm)
import Translations.Forms exposing (related)
import Translations.Labels exposing (loading, onError)
import Translations.Titles exposing (snippets, terms)
import UI.Button exposing (defaultButton)
import UI.Card exposing (keyedCard)
import UI.Dialog exposing (defaultDialog)
import UI.Dropdown exposing (Dropdown, dropdown, initModel, updateModel)
import Uuid exposing (Uuid)
import Validate exposing (Valid, fromValid, validate)
import View exposing (View)


page : Auth.User -> Shared.Model -> Route () -> Page Model Msg
page user shared _ =
    Page.new
        { init = init user
        , update = update user
        , subscriptions = \_ -> Sub.none
        , view = view user shared
        }
        |> Page.withLayout (layout shared)


layout : Shared.Model -> Model -> Layouts.Layout Msg
layout shared _ =
    Layouts.Layout { shared = shared }



-- INIT


type alias Model =
    { state : State
    , toUpdate : Maybe EditTerm
    , toDelete : Maybe Uuid
    , termsDropdown : Dropdown
    }


type State
    = Loading
    | Loaded (List TermResponse)
    | Errored String


init : Auth.User -> () -> ( Model, Effect Msg )
init user _ =
    loadTerms user



-- UPDATE


type Msg
    = TermsLoaded (Result Http.Error (List TermResponse))
    | TermDeleted (Result Http.Error ())
    | UpdateTerm (Result Http.Error ())
    | ClickedNew
    | ClickedSnippets TermResponse
    | Edit EditTerm
    | ChangedDropdown (ChangeEvent TermResponse)
    | ClickedCancelEdit
    | ClickedSubmitEdit (Result (List ( ValidationField, String )) (Valid EditTerm))
    | ClickedDelete Uuid
    | ClickedCancelDelete
    | ClickedSubmitDelete


update : Auth.User -> Msg -> Model -> ( Model, Effect Msg )
update user msg model =
    case msg of
        TermsLoaded (Ok list) ->
            ( { model | state = Loaded list }, Effect.none )

        TermsLoaded (Err err) ->
            if isUnauthenticated err then
                ( model, Effect.signOut )

            else
                ( { model | state = Errored (Problem.toString err) }, Effect.none )

        TermDeleted (Ok _) ->
            loadTerms user

        TermDeleted (Err err) ->
            if isUnauthenticated err then
                ( model, Effect.signOut )

            else
                ( { model | state = Errored (Problem.toString err) }, Effect.none )

        UpdateTerm (Ok _) ->
            loadTerms user

        UpdateTerm (Err err) ->
            if isUnauthenticated err then
                ( model, Effect.signOut )

            else
                ( { model | state = Errored (Problem.toString err) }, Effect.none )

        ClickedNew ->
            ( model
            , Effect.pushRoute
                { path = Route.Path.Terms_New
                , query = Dict.empty
                , hash = Nothing
                }
            )

        ClickedSnippets term ->
            ( model
            , Effect.pushRoute
                { path = Route.Path.Snippets
                , query =
                    Dict.fromList
                        [ ( "termID", Uuid.toString term.id )
                        , ( "name", term.name )
                        ]
                , hash = Nothing
                }
            )

        Edit term ->
            ( { model | toUpdate = Just term }, Effect.none )

        ChangedDropdown changeEvent ->
            case ( model.toUpdate, changeEvent ) of
                ( Just toUpdate, SelectionChanged sth ) ->
                    ( { model | termsDropdown = updateModel (TextChanged "") model.termsDropdown, toUpdate = Just { toUpdate | related = Dict.insert (Uuid.toString sth.id) sth.name toUpdate.related } }, Effect.none )

                _ ->
                    ( { model | termsDropdown = updateModel changeEvent model.termsDropdown }, Effect.none )

        ClickedCancelEdit ->
            ( { model | toUpdate = Nothing }, Effect.none )

        ClickedSubmitEdit (Ok input) ->
            let
                valid : EditTerm
                valid =
                    fromValid input
            in
            updateTerm user valid.id { name = valid.name, related = List.concatMap uuidFromString (Dict.keys valid.related) }

        ClickedSubmitEdit (Err list) ->
            case model.toUpdate of
                Just some ->
                    ( { model | toUpdate = Just { some | errors = list } }, Effect.none )

                _ ->
                    ( model, Effect.none )

        ClickedDelete id ->
            ( { model | toDelete = Just id }, Effect.none )

        ClickedCancelDelete ->
            ( { model | toDelete = Nothing }, Effect.none )

        ClickedSubmitDelete ->
            case model.toDelete of
                Just id ->
                    deleteTerm user id

                Nothing ->
                    ( model, Effect.none )



-- VIEW


view : Auth.User -> Shared.Model -> Model -> View Msg
view user shared model =
    { title = terms shared.translations
    , elements = viewTerms user shared model
    }


viewTerms : Auth.User -> Shared.Model -> Model -> List (Element Msg)
viewTerms user shared model =
    case model.state of
        Loading ->
            [ text (loading shared.translations) ]

        Loaded terms ->
            case ( user.role, model.toUpdate, model.toDelete ) of
                ( RoleAdmin, Just toUpdate, _ ) ->
                    [ editTerm shared toUpdate model terms ]

                ( RoleAdmin, _, Just _ ) ->
                    [ defaultDialog shared.translations ClickedCancelDelete ClickedSubmitDelete ]

                ( RoleAdmin, _, _ ) ->
                    defaultButton (newTerm shared.translations) ClickedNew :: List.map (viewTerm shared True terms) terms

                ( RoleUser, _, _ ) ->
                    List.map (viewTerm shared False terms) terms

        Errored reason ->
            [ text (onError shared.translations reason) ]


relatedUuidToText : List Uuid -> List TermResponse -> List String
relatedUuidToText related all =
    List.concatMap (\v -> termsToTexts all v) related


termsToTexts : List TermResponse -> Uuid -> List String
termsToTexts related id =
    List.filterMap (\r -> findTermText r id) related


findTermText : TermResponse -> Uuid -> Maybe String
findTermText r id =
    if r.id == id then
        Just r.name

    else
        Nothing


termsToText : List TermResponse -> Uuid -> String
termsToText related id =
    case termsToTexts related id of
        [ v ] ->
            v

        _ ->
            ""


viewTerm : Shared.Model -> Bool -> List TermResponse -> TermResponse -> Element Msg
viewTerm shared canEdit all term =
    let
        buttons : List (Element Msg)
        buttons =
            if canEdit then
                [ defaultButton (snippets shared.translations) click
                , defaultButton (edit shared.translations) (Edit (editTermFromTerm term all))
                , defaultButton (delete shared.translations) (ClickedDelete term.id)
                ]

            else
                [ defaultButton (snippets shared.translations) click ]

        click : Msg
        click =
            ClickedSnippets term

        body : Element msg
        body =
            paragraph [ Font.size 16 ] [ text (String.join ", " (relatedUuidToText term.related all)) ]
    in
    keyedCard { title = term.name, rightLabel = "", body = [ body ], onClick = Just click, buttons = buttons } term.id


editTerm : Shared.Model -> EditTerm -> Model -> List TermResponse -> Element Msg
editTerm shared term model terms =
    let
        submit : Msg
        submit =
            ClickedSubmitEdit (validate (editTermValidator shared.translations) term)

        dd : Element Msg
        dd =
            dropdown (related shared.translations) model.termsDropdown terms ChangedDropdown []
    in
    editForm shared.translations term dd Edit ClickedCancelEdit submit


deleteTerm : Auth.User -> Uuid -> ( Model, Effect Msg )
deleteTerm session id =
    ( { state = Loading, toUpdate = Nothing, toDelete = Nothing, termsDropdown = initModel }
    , Effect.sendCmd (Api.send TermDeleted (deleteTerms id session.token))
    )


updateTerm : Auth.User -> Uuid -> UpdateTerm -> ( Model, Effect Msg )
updateTerm session id term =
    ( { state = Loading, toUpdate = Nothing, toDelete = Nothing, termsDropdown = initModel }
    , Effect.sendCmd (Api.send UpdateTerm (updateTerms id term session.token))
    )


loadTerms : Auth.User -> ( Model, Effect Msg )
loadTerms session =
    ( { state = Loading, toUpdate = Nothing, toDelete = Nothing, termsDropdown = initModel }
    , Effect.sendCmd (Api.send TermsLoaded (readAllTerms session.token))
    )


editTermFromTerm : TermResponse -> List TermResponse -> EditTerm
editTermFromTerm model all =
    { id = model.id
    , title = model.name
    , name = model.name
    , related = List.foldl (\id dict -> Dict.insert (Uuid.toString id) (termsToText all id) dict) Dict.empty model.related
    , errors = []
    }



-- SUBSCRIPTIONS
