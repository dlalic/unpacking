module Problem exposing (isUnauthenticated, toString)

import Http


isUnauthenticated : Http.Error -> Bool
isUnauthenticated =
    isStatus 401


isStatus : Int -> Http.Error -> Bool
isStatus status error =
    case error of
        Http.BadStatus httpStatus ->
            status == httpStatus

        _ ->
            False


toString : Http.Error -> String
toString err =
    case err of
        Http.BadUrl message ->
            message

        Http.Timeout ->
            "Timeout"

        Http.NetworkError ->
            "Network error"

        Http.BadStatus code ->
            "Bad status " ++ String.fromInt code

        Http.BadBody message ->
            message
