@target(erlang)
import gleam/result
@target(erlang)
import marmot.{type ResetError}
@target(erlang)
import simplifile
@target(erlang)
import sqlight.{type Connection}

@target(erlang)
pub type SetupError {
  CreateDirectoryFailed
  ResetFailed(reason: ResetError)
  OpenFailed
}

@target(erlang)
pub fn setup(name name: String) -> Result(Connection, SetupError) {
  let root = "./tmp/test-db"
  use _ <- result.try(
    simplifile.create_directory_all(root)
    |> result.map_error(fn(_) { CreateDirectoryFailed }),
  )
  let path = root <> "/scoreboard-" <> name <> ".db"

  case marmot.reset(path) {
    Ok(_) ->
      sqlight.open(path)
      |> result.map_error(fn(_) { OpenFailed })
    Error(error) -> Error(ResetFailed(error))
  }
}
