# Keep arithmetic within JIT-compilable arity

Steel 0.8.3's JIT panics while compiling variadic arithmetic above a small
operand count: `couldn't match the name for the op code + payload: (ADD, 5)`.
The panic aborts the process, so it reaches Grove through Helix as well as
through `steel tests/domain.scm`. Observed limits are four operands for `+` and
three for `-` and `*`.

Write arithmetic in Grove with at most three operands per `+`, `-`, or `*`
call. Name the intermediate parts in a helper instead of extending one
expression. Domain law tests fail loudly when a change crosses the limit.

Revisit when Grove runs a Steel build whose JIT compiles wider arithmetic and
`make test` passes without the restriction.
