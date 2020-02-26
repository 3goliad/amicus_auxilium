import logo from "./logo.svg";
import { Elm } from "./src/Main.elm";
Elm.Main.init({
    flags: {
        logo: logo
    }
});
