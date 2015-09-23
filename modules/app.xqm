xquery version "3.0";

module namespace app="http://history.state.gov/ns/site/hsg/templates";

import module namespace templates="http://exist-db.org/xquery/templates" ;
import module namespace config="http://history.state.gov/ns/site/hsg/config" at "config.xqm";
import module namespace console="http://exist-db.org/xquery/console" at "java:org.exist.console.xquery.ConsoleModule";

declare
    %templates:wrap
function app:hide-if-empty($node as node(), $model as map(*), $property as xs:string) {
        if (empty($model($property))) then
            attribute style { "display: none" }
        else
            (),
        templates:process($node/node(), $model)
};

declare
    %templates:wrap
function app:fix-links($node as node(), $model as map(*)) {
    templates:process(app:fix-links($node/node()), $model)
};

declare function app:fix-links($nodes as node()*) {
    for $node in $nodes
    return
        typeswitch($node)
            case element(a) | element(link) return
                (: skip links with @data-template attributes; otherwise we can run into duplicate @href errors :)
                if ($node/@data-template) then 
                    $node 
                else
                    let $href := 
                        replace(
                            replace($node/@href, "\$extern", "http://history.state.gov"),
                            "\$app",
                            (request:get-context-path() || "/apps/hsg-shell")
                        )
                    return
                        element { node-name($node) } {
                            attribute href {$href}, $node/@* except $node/@href, app:fix-links($node/node())
                        }
            case  element(img) | element(script) return
                (: skip links with @data-template attributes; otherwise we can run into duplicate @src errors :)
                if ($node/@data-template) then 
                    $node 
                else
                    let $src := 
                        replace(
                            replace($node/@src, "\$extern", "http://history.state.gov"),
                            "\$app",
                            (request:get-context-path() || "/apps/hsg-shell")
                        )
                    return
                        element { node-name($node) } {
                            attribute src {$src}, $node/@* except $node/@src, $node/node()
                        }
            case element() return
                element { node-name($node) } {
                    $node/@*, app:fix-links($node/node())
                }
            default return
                $node
};

declare
    %templates:wrap
function app:handle-error($node as node(), $model as map(*), $code as xs:integer?) {
    let $errcode := request:get-attribute("hsg-shell.errcode")
    let $log := console:log("error: " || $errcode || " code: " || $code)
    return
        if ((empty($errcode) and empty($code)) or $code = $errcode) then
            templates:process($node/node(), $model)
        else
            ()
};

declare function app:uri($node as node(), $model as map(*)) {
    <code>{request:get-attribute("hsg-shell.path")}</code>
};

declare function app:parse-params($node as node(), $model as map(*)) {
    element { node-name($node) } {
        for $attr in $node/@*
        return
            if (matches($attr, "\$\{[^\}]+\}")) then
                attribute { node-name($attr) } {
                    string-join(
                        let $parsed := analyze-string($attr, "\$\{([^\}]+?)(?:\:([^\}]+))?\}")
                        for $token in $parsed/node()
                        return
                            typeswitch($token)
                                case element(fn:non-match) return $token/string()
                                case element(fn:match) return
                                    let $paramName := $token/fn:group[1]
                                    let $default := $token/fn:group[2]
                                    return
                                        (request:get-parameter($paramName, $default), $model?($paramName))[1]
                                default return $token
                    )
                }
            else
                $attr,
        templates:process($node/node(), $model)
    }
};

declare function app:available-pages($node as node(), $model as map(*)) {
    <ul data-template="app:fix-links">
        {
        let $available-pages := doc($config:app-root || '/templates/site.html')//div[@id = 'navbar-collapse-1']//a[starts-with(@href, '$app')][not(@class = 'dropdown-toggle')]
        for $link in $available-pages
        return
            <li>
                {element {node-name($link)} {$link/@href, $link/string()}}
            </li>
        }
    </ul>
};
