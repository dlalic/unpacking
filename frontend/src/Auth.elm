module Auth exposing
    ( User
    , beforeProtectedInit
    )

import Domain.Session
import ElmSpa.Page as ElmSpa
import Gen.Route exposing (Route)
import Request exposing (Request)
import Shared


type alias User =
    Domain.Session.Session


beforeProtectedInit : Shared.Model -> Request -> ElmSpa.Protected User Route
beforeProtectedInit { storage } _ =
    case storage.session of
        Just session ->
            ElmSpa.Provide session

        Nothing ->
            ElmSpa.RedirectTo Gen.Route.SignIn
