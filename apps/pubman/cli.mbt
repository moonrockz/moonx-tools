///|
struct CommandContract {
  name : String
  input : String
  mutates : Bool
}

///|
let commands : Array[CommandContract] = [
  { name: "plan", input: "config", mutates: false, },
  { name: "pack", input: "config", mutates: true, },
  { name: "verify", input: "bundle", mutates: true, },
  { name: "publish", input: "bundle", mutates: true, },
]

///|
fn command_tree() -> @argparse.Command {
  @argparse.Command(
    "pubman",
    version="pubman " + version,
    about="Package one MoonBit library for Mooncakes and npm",
    subcommand_required=true,
    flags=[@argparse.FlagArg("json", global=true, about="Emit schema v1 JSON")],
    subcommands=commands.map(c => {
        @argparse.Command(
          c.name[:],
          options=[@argparse.OptionArg(c.input[:], required=true)],
          flags=if c.mutates {
            [
              @argparse.FlagArg(
                "dry-run",
                about="Preview using local reads only",
              ),
            ]
          } else {
            []
          },
        )
      })[:],
  )
}

///|
struct Request {
  command : String
  input : String
  json : Bool
  preview : Bool
}

///|
fn request(argv : Array[String]) -> Request raise {
  let parsed = command_tree().parse(argv=argv[:])
  guard parsed.subcommand is Some((command, m)) else {
    abort("subcommand required")
  }
  let contract = commands.filter(c => c.name == command)[0]
  {
    command,
    input: m.values[contract.input][0],
    json: m.flags.get("json").unwrap_or(false),
    preview: m.flags.get("dry-run").unwrap_or(false),
  }
}
