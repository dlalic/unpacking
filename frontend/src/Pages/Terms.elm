module Pages.Terms exposing (Model, Msg, State, page)

import Api
import Api.Data exposing (Role(..), TermResponse, UpdateTerm)
import Api.Request.Default exposing (deleteTerms, readAllTerms, updateTerms)
import Auth
import Common exposing (uuidFromString)
import Dict
import Element exposing (Element, paragraph, text)
import Element.Font as Font
import Forms.TermForm exposing (EditTerm, editForm, editTermValidator)
import Forms.Validators exposing (ValidationField)
import Gen.Route as Route
import Http
import Page
import Problem exposing (isUnauthenticated)
import Request exposing (Request)
import SearchBox exposing (ChangeEvent(..))
import Shared
import Storage exposing (Storage)
import Translations.Buttons exposing (delete, edit, newTerm)
import Translations.Forms exposing (related)
import Translations.Labels exposing (loading, onError)
import Translations.Titles exposing (terms)
import UI.Button exposing (defaultButton)
import UI.Card exposing (keyedCard)
import UI.Dialog exposing (defaultDialog)
import UI.Dropdown exposing (Dropdown, dropdown, initModel, updateModel)
import UI.Layout as Layout
import Uuid exposing (Uuid)
import Validate exposing (Valid, fromValid, validate)
import View exposing (View)


page : Shared.Model -> Request -> Page.With Model Msg
page shared req =
    Page.protected.element
        (\session ->
            { init = init session
            , update = update req shared.storage
            , view = view shared
            , subscriptions = \_ -> Sub.none
            }
        )


type alias Model =
    { session : Auth.User
    , state : State
    , toUpdate : Maybe EditTerm
    , toDelete : Maybe Uuid
    , termsDropdown : Dropdown TermResponse
    }


type State
    = Loading
    | Loaded (List TermResponse)
    | Errored String


init : Auth.User -> ( Model, Cmd Msg )
init session =
    loadTerms session


type Msg
    = TermsLoaded (Result Http.Error (List TermResponse))
    | TermDeleted (Result Http.Error ())
    | UpdateTerm (Result Http.Error ())
    | ClickedNew
    | ClickedView Uuid
    | Edit EditTerm
    | ChangedDropdown (ChangeEvent TermResponse)
    | ClickedCancelEdit
    | ClickedSubmitEdit (Result (List ( ValidationField, String )) (Valid EditTerm))
    | ClickedDelete Uuid
    | ClickedCancelDelete
    | ClickedSubmitDelete


update : Request -> Storage -> Msg -> Model -> ( Model, Cmd Msg )
update req storage msg model =
    case msg of
        TermsLoaded (Ok list) ->
            ( { model | state = Loaded list }, Cmd.none )

        TermsLoaded (Err err) ->
            if isUnauthenticated err then
                ( model, Storage.signOut storage )

            else
                ( { model | state = Errored (Problem.toString err) }, Cmd.none )

        TermDeleted (Ok _) ->
            loadTerms model.session

        TermDeleted (Err err) ->
            if isUnauthenticated err then
                ( model, Storage.signOut storage )

            else
                ( { model | state = Errored (Problem.toString err) }, Cmd.none )

        UpdateTerm (Ok _) ->
            loadTerms model.session

        UpdateTerm (Err err) ->
            if isUnauthenticated err then
                ( model, Storage.signOut storage )

            else
                ( { model | state = Errored (Problem.toString err) }, Cmd.none )

        ClickedNew ->
            ( model, Request.pushRoute Route.Terms__New req )

        -- TODO: Request.pushRoute (Route.Users__Id___Transactions { id = Uuid.toString id }) req
        ClickedView _ ->
            ( model, Cmd.none )

        Edit term ->
            ( { model | toUpdate = Just term }, Cmd.none )

        ChangedDropdown changeEvent ->
            case ( model.toUpdate, changeEvent ) of
                ( Just toUpdate, SelectionChanged sth ) ->
                    ( { model | termsDropdown = updateModel (TextChanged "") model.termsDropdown, toUpdate = Just { toUpdate | related = Dict.insert (Uuid.toString sth.id) sth.name toUpdate.related } }, Cmd.none )

                _ ->
                    ( { model | termsDropdown = updateModel changeEvent model.termsDropdown }, Cmd.none )

        ClickedCancelEdit ->
            ( { model | toUpdate = Nothing }, Cmd.none )

        ClickedSubmitEdit (Ok input) ->
            let
                valid : EditTerm
                valid =
                    fromValid input
            in
            updateTerm model.session valid.id { name = valid.name, related = List.concatMap uuidFromString (Dict.keys valid.related) }

        ClickedSubmitEdit (Err list) ->
            case model.toUpdate of
                Just some ->
                    ( { model | toUpdate = Just { some | errors = list } }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        ClickedDelete id ->
            ( { model | toDelete = Just id }, Cmd.none )

        ClickedCancelDelete ->
            ( { model | toDelete = Nothing }, Cmd.none )

        ClickedSubmitDelete ->
            case model.toDelete of
                Just id ->
                    deleteTerm model.session id

                Nothing ->
                    ( model, Cmd.none )


view : Shared.Model -> Model -> View Msg
view shared model =
    { title = terms shared.translations
    , body =
        Layout.layout Route.Terms shared (viewTerms shared model)
    }


viewTerms : Shared.Model -> Model -> List (Element Msg)
viewTerms shared model =
    case model.state of
        Loading ->
            [ text (loading shared.translations) ]

        Loaded terms ->
            case ( model.session.role, model.toUpdate, model.toDelete ) of
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
        onClick : Msg
        onClick =
            ClickedView term.id

        buttons : List (Element Msg)
        buttons =
            if canEdit then
                [ defaultButton (Translations.Buttons.view shared.translations) onClick
                , defaultButton (edit shared.translations) (Edit (editTermFromTerm term all))
                , defaultButton (delete shared.translations) (ClickedDelete term.id)
                ]

            else
                [ defaultButton (Translations.Buttons.view shared.translations) onClick ]

        body : Element msg
        body =
            paragraph [ Font.size 16 ] [ text (String.join ", " (relatedUuidToText term.related all)) ]
    in
    keyedCard { title = term.name, rightLabel = "", body = [ body ], onClick = Just onClick, buttons = buttons } term.id


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


deleteTerm : Auth.User -> Uuid -> ( Model, Cmd Msg )
deleteTerm session id =
    ( { session = session, state = Loading, toUpdate = Nothing, toDelete = Nothing, termsDropdown = initModel }
    , Api.send TermDeleted (deleteTerms id session.token)
    )


updateTerm : Auth.User -> Uuid -> UpdateTerm -> ( Model, Cmd Msg )
updateTerm session id term =
    ( { session = session, state = Loading, toUpdate = Nothing, toDelete = Nothing, termsDropdown = initModel }
    , Api.send UpdateTerm (updateTerms id term session.token)
    )


loadTerms : Auth.User -> ( Model, Cmd Msg )
loadTerms session =
    ( { session = session, state = Loading, toUpdate = Nothing, toDelete = Nothing, termsDropdown = initModel }
    , Api.send TermsLoaded (readAllTerms session.token)
    )


editTermFromTerm : TermResponse -> List TermResponse -> EditTerm
editTermFromTerm model all =
    { id = model.id
    , title = model.name
    , name = model.name
    , related = List.foldl (\id dict -> Dict.insert (Uuid.toString id) (termsToText all id) dict) Dict.empty model.related
    , errors = []
    }
