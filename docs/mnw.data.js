import { loadOptions, stripNixStore } from "easy-nix-documentation/loader"
export default {
    async load() {
        const optionsJSON = process.env.MNW_OPTIONS_JSON
        if (optionsJSON === undefined) {
            console.log("MNW_OPTIONS_JSON is undefined");
            exit(1)
        }
        return await loadOptions(optionsJSON, {
            include: [/programs\.mnw\.*/],
            mapDeclarations: declaration => {
                const relDecl = stripNixStore(declaration);
                return `<a href="https://github.com/Gerg-L/mnw/tree/master/${relDecl}">&lt;mnw/${relDecl}&gt;</a>`
            },
        })
    }
}
