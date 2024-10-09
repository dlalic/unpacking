module Pages.Users.New exposing (Model, Msg, State, page)

import Api
import Api.Data exposing (CreateUser)
import Api.Request.Default exposing (createUsers)
import Auth
import Dict
import Effect exposing (Effect)
import Element exposing (Element, text)
import Forms.UserForm exposing (NewUser, defaultNew, newForm, newUserValidator)
import Forms.Validators exposing (ValidationField)
import Http
import Layouts
import Page exposing (Page)
import Problem exposing (isUnauthenticated)
import Route exposing (Route)
import Route.Path
import Shared
import Translations.Buttons exposing (newUser)
import Translations.Labels exposing (loading, onError)
import Uuid exposing (Uuid)
import Validate exposing (Valid, fromValid, validate)
import View exposing (View)


page : Auth.User -> Shared.Model -> Route () -> Page Model Msg
page user shared _ =
    Page.new
        { init = init
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
    , toCreate : NewUser
    }


type State
    = Loading
    | Loaded
    | Errored String


init : () -> ( Model, Effect Msg )
init _ =
    ( { state = Loaded, toCreate = defaultNew }, Effect.none )



-- UPDATE


type Msg
    = Edit NewUser
    | ClickedCancel
    | ClickedSubmit (Result (List ( ValidationField, String )) (Valid NewUser))
    | Created (Result Http.Error Uuid)


update : Auth.User -> Msg -> Model -> ( Model, Effect Msg )
update user msg model =
    case msg of
        Edit new ->
            ( { model | toCreate = new }, Effect.none )

        ClickedCancel ->
            ( model
            , Effect.pushRoute
                { path = Route.Path.Users
                , query = Dict.empty
                , hash = Nothing
                }
            )

        ClickedSubmit (Ok input) ->
            createUser user model (fromValid input)

        ClickedSubmit (Err list) ->
            let
                toCreate : NewUser -> NewUser
                toCreate userToCreate =
                    { userToCreate | errors = list }
            in
            ( { model | toCreate = toCreate model.toCreate }, Effect.none )

        Created (Ok _) ->
            ( model
            , Effect.pushRoute
                { path = Route.Path.Users
                , query = Dict.empty
                , hash = Nothing
                }
            )

        Created (Err err) ->
            if isUnauthenticated err then
                ( model, Effect.signOut )

            else
                ( { model | state = Errored (Problem.toString err) }, Effect.none )



-- VIEW


view : Shared.Model -> Model -> View Msg
view shared model =
    { title = newUser shared.translations
    , elements = viewForm shared model
    }


viewForm : Shared.Model -> Model -> List (Element Msg)
viewForm shared model =
    let
        submit : Msg
        submit =
            ClickedSubmit (validate (newUserValidator shared.translations) model.toCreate)
    in
    case model.state of
        Loading ->
            [ text (loading shared.translations) ]

        Loaded ->
            [ newForm shared.translations model.toCreate Edit ClickedCancel submit ]

        Errored reason ->
            [ text (onError shared.translations reason) ]


createUser : Auth.User -> Model -> NewUser -> ( Model, Effect Msg )
createUser user model newUser =
    ( { model | state = Loading }
    , Effect.sendCmd (Api.send Created (createUsers (createUserFrom newUser) user.token))
    )


createUserFrom : NewUser -> CreateUser
createUserFrom model =
    { name = model.name
    , role = model.role
    , email = model.email
    , password = model.password
    }



-- SUBSCRIPTIONS
