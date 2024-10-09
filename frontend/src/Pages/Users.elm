module Pages.Users exposing (Model, Msg, State, page)

import Api
import Api.Data exposing (Role(..), UpdateUser, UserResponse)
import Api.Request.Default exposing (deleteUsers, readAllUsers, updateUsers)
import Auth
import Dict
import Effect exposing (Effect)
import Element exposing (Element, text)
import Forms.UserForm exposing (EditUser, editForm, editUserValidator, stringFromRole)
import Forms.Validators exposing (ValidationField)
import Http
import Layouts
import Page exposing (Page)
import Problem exposing (isUnauthenticated)
import Route exposing (Route)
import Route.Path
import Shared
import Translations.Buttons exposing (delete, edit, newUser)
import Translations.Labels exposing (loading, onError)
import Translations.Titles exposing (users)
import UI.Button exposing (defaultButton)
import UI.Card exposing (keyedCard)
import UI.Dialog exposing (defaultDialog)
import Uuid exposing (Uuid)
import Validate exposing (Valid, fromValid, validate)
import View exposing (View)


page : Auth.User -> Shared.Model -> Route () -> Page Model Msg
page user shared _ =
    Page.new
        { init = init user
        , update = update user
        , subscriptions = \_ -> Sub.none
        , view = view shared
        }
        |> Page.withLayout (layout shared)


layout : Shared.Model -> Model -> Layouts.Layout Msg
layout shared _ =
    Layouts.Layout { shared = shared }



-- INIT


type alias Model =
    { state : State
    , toUpdate : Maybe EditUser
    , toDelete : Maybe Uuid
    }


type State
    = Loading
    | Loaded (List UserResponse)
    | Errored String


init : Auth.User -> () -> ( Model, Effect Msg )
init user _ =
    loadUsers user



-- UPDATE


type Msg
    = UsersLoaded (Result Http.Error (List UserResponse))
    | UserDeleted (Result Http.Error ())
    | UserUpdated (Result Http.Error ())
    | ClickedNew
    | Edit EditUser
    | ClickedCancelEdit
    | ClickedSubmitEdit (Result (List ( ValidationField, String )) (Valid EditUser))
    | ClickedDelete Uuid
    | ClickedCancelDelete
    | ClickedSubmitDelete


update : Auth.User -> Msg -> Model -> ( Model, Effect Msg )
update user msg model =
    case msg of
        UsersLoaded (Ok list) ->
            ( { model | state = Loaded list }, Effect.none )

        UsersLoaded (Err err) ->
            if isUnauthenticated err then
                ( model, Effect.signOut )

            else
                ( { model | state = Errored (Problem.toString err) }, Effect.none )

        ClickedNew ->
            ( model
            , Effect.pushRoute
                { path = Route.Path.Users_New
                , query = Dict.empty
                , hash = Nothing
                }
            )

        Edit selectedUser ->
            ( { model | toUpdate = Just selectedUser }, Effect.none )

        ClickedCancelEdit ->
            ( { model | toUpdate = Nothing }, Effect.none )

        ClickedSubmitEdit (Ok input) ->
            let
                valid : EditUser
                valid =
                    fromValid input
            in
            updateUser user valid.id { name = valid.name, email = valid.email, role = valid.role }

        ClickedSubmitEdit (Err list) ->
            case model.toUpdate of
                Just some ->
                    ( { model | toUpdate = Just { some | errors = list } }, Effect.none )

                _ ->
                    ( model, Effect.none )

        UserUpdated (Ok _) ->
            loadUsers user

        UserUpdated (Err err) ->
            if isUnauthenticated err then
                ( model, Effect.signOut )

            else
                ( { model | state = Errored (Problem.toString err) }, Effect.none )

        ClickedDelete uuid ->
            ( { model | toDelete = Just uuid }, Effect.none )

        ClickedCancelDelete ->
            ( { model | toDelete = Nothing }, Effect.none )

        ClickedSubmitDelete ->
            case model.toDelete of
                Just uuid ->
                    deleteUser user uuid

                Nothing ->
                    ( model, Effect.none )

        UserDeleted (Ok _) ->
            loadUsers user

        UserDeleted (Err err) ->
            if isUnauthenticated err then
                ( model, Effect.signOut )

            else
                ( { model | state = Errored (Problem.toString err) }, Effect.none )



-- VIEW


view : Shared.Model -> Model -> View Msg
view shared model =
    { title = users shared.translations
    , elements = viewUsers shared model
    }


viewUsers : Shared.Model -> Model -> List (Element Msg)
viewUsers shared model =
    case model.state of
        Loading ->
            [ text (loading shared.translations) ]

        Loaded list ->
            case ( model.toUpdate, model.toDelete ) of
                ( Just toUpdate, _ ) ->
                    [ editUser shared toUpdate ]

                ( _, Just _ ) ->
                    [ defaultDialog shared.translations ClickedCancelDelete ClickedSubmitDelete ]

                _ ->
                    defaultButton (newUser shared.translations) ClickedNew :: List.map (viewUser shared) list

        Errored reason ->
            [ text (onError shared.translations reason) ]


viewUser : Shared.Model -> UserResponse -> Element Msg
viewUser shared user =
    let
        rightLabel : String
        rightLabel =
            case user.role of
                RoleAdmin ->
                    stringFromRole shared.translations user.role

                _ ->
                    ""

        buttons : List (Element Msg)
        buttons =
            [ defaultButton (edit shared.translations) (Edit (editUserFromUser user))
            , defaultButton (delete shared.translations) (ClickedDelete user.id)
            ]
    in
    keyedCard { title = user.name, rightLabel = rightLabel, body = [], onClick = Nothing, buttons = buttons } user.id


editUser : Shared.Model -> EditUser -> Element Msg
editUser shared user =
    let
        submit : Msg
        submit =
            ClickedSubmitEdit (validate (editUserValidator shared.translations) user)
    in
    editForm shared.translations user Edit ClickedCancelEdit submit


deleteUser : Auth.User -> Uuid -> ( Model, Effect Msg )
deleteUser user uuid =
    ( { state = Loading, toUpdate = Nothing, toDelete = Nothing }
    , Effect.sendCmd (Api.send UserDeleted (deleteUsers uuid user.token))
    )


updateUser : Auth.User -> Uuid -> UpdateUser -> ( Model, Effect Msg )
updateUser user id updatedUser =
    ( { state = Loading, toUpdate = Nothing, toDelete = Nothing }
    , Effect.sendCmd (Api.send UserUpdated (updateUsers id updatedUser user.token))
    )


loadUsers : Auth.User -> ( Model, Effect Msg )
loadUsers user =
    ( { state = Loading, toUpdate = Nothing, toDelete = Nothing }
    , Effect.sendCmd (Api.send UsersLoaded (readAllUsers user.token))
    )


editUserFromUser : UserResponse -> EditUser
editUserFromUser model =
    { id = model.id
    , title = model.name
    , name = model.name
    , email = model.email
    , role = model.role
    , errors = []
    }
