module Common exposing (errorsForField, uuidFromString)

import Uuid exposing (Uuid)


errorsForField : a -> List ( a, String ) -> List String
errorsForField field errors =
    List.map (\( _, error ) -> error) (List.filter (\( fieldError, _ ) -> fieldError == field) errors)


uuidFromString : String -> List Uuid
uuidFromString v =
    case Uuid.fromString v of
        Just a ->
            [ a ]

        Nothing ->
            []
