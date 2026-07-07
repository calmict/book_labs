# Chapter 14 — Answers

## The closed door (Phase 0)

    # paste the line where the plan refuses the missing variable:

## The bouncer (Phase 1)

    # paste the line where validation rejects environment=banana:

## The three entrances (Phase 2)

    # tfvars says environment=dev, and you run: tofu plan -var environment=prod
    # paste the plan line that proves who won (the container name):

## The three questions

**a. The three doors.**

_(3-5 lines: environment / container_name / url mapped to front / service /
internal kitchen; why container_name is neither a variable nor an output)_

**b. Precedence.**

_(3-5 lines: which environment is applied with tfvars=dev + TF_VAR_=staging +
-var=prod, the general rule, why the CLI winning makes sense)_

**c. tfvars and the secret.**

_(3-5 lines: why .gitignore excludes tfvars and only .example travels; the
thread linking this to chapter 11's plain-text state)_
