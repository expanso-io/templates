# PRD: Expanso Templates & Walkthroughs Repository

## Executive Summary

Create a centralized, validated repository of **25 production-ready pipeline templates** and **20 in-depth walkthroughs** that demonstrate Expanso's edge data processing capabilities. This "cookbook" serves as the primary resource for users moving from documentation to working deployments, dramatically reducing time-to-value and supporting the full journey from "hello world" to production-grade, multi-cloud deployments.

The repository addresses a critical gap: new and intermediate users consistently struggle to translate conceptual documentation into functional pipelines. By providing copy-paste-ready templates with explanatory walkthroughs, we eliminate the "activation wall" that causes user attrition during onboarding.

---

## Problem Statement / Opportunity

### The Core Problem

Users exploring Expanso encounter significant friction when moving from reading documentation to deploying working pipelines. Examples are fragmented across multiple locations (`docs.expanso.io`, `examples.expanso.io`, community forums, blog posts) with no single curated, validated repository. This creates three compounding issues:

1. **Fragmentation**: Users cannot find complete, working examples for common use cases.
2. **Validation Uncertainty**: Existing scattered examples may be outdated, incomplete, or incompatible with current Expanso versions.
3. **Progression Gap**: No clear path from beginner patterns to enterprise-grade deployments.

### Evidence of Pain

- Community forums show a high volume of "getting started" and "example request" threads, indicating users are searching for working configurations they can adapt.
- Support channels frequently receive requests for "complete YAML for [common use case]" rather than component-level questions.
- User feedback during onboarding interviews highlights difficulty translating component documentation into end-to-end pipelines.
- The existing `examples.expanso.io` has not been updated in sync with recent Expanso releases, causing compatibility issues.

### The Opportunity

A single source of truth for validated, progressive examples will:
- **Reduce time-to-first-pipeline** by providing copy-paste starting points
- **Increase adoption of advanced features** through clear progression paths
- **Lower support burden** by preemptively answering common integration questions
- **Build community engagement** through a contribution model

---

## Target Users / Personas

### Persona 1: Alex, the New Data Engineer (Primary)

| Attribute | Description |
|-----------|-------------|
| **Role** | Mid-level Data Engineer at a growth-stage company |
| **Experience** | 3-5 years in data engineering; proficient in YAML, Python, SQL, cloud services |
| **Goal** | Evaluate and prototype Expanso to replace a legacy batch ETL tool with real-time streaming |
| **Context** | First-time Expanso user, comfortable with data concepts but new to Expanso's specific syntax |
| **Current Behavior** | Searches GitHub for "[tool] examples", prefers learning by running code, bookmarks useful repos. Currently spends hours piecing together examples from docs and forums. |
| **Pain Points** | Overwhelmed by component-level documentation; needs "copy-paste-and-tweak" starting points; unclear what production-ready configs look like |
| **Success Looks Like** | Deploys a working Kafka-to-Snowflake pipeline within 2 hours of discovering the repository |

### Persona 2: Sam, the DevOps Practitioner (Primary)

| Attribute | Description |
|-----------|-------------|
| **Role** | Senior DevOps Engineer responsible for observability infrastructure |
| **Experience** | 5+ years in DevOps; expert in infrastructure-as-code, CI/CD, monitoring |
| **Goal** | Deploy robust, observable edge data pipelines with proper error handling |
| **Context** | Less focused on complex transformations, more on reliability and security |
| **Current Behavior** | Reviews code before running it, checks for security warnings, evaluates maintainability. Currently hesitant to adopt new tools without proven patterns. |
| **Pain Points** | Needs proven patterns for reliability (circuit breakers, DLQs); worried about deploying unvetted configurations to production; wants templates that integrate cleanly with existing CI/CD |
| **Success Looks Like** | Finds and adapts a dead-letter-queue template, integrating it into a CI/CD staging pipeline within 1 business day |

### Persona 3: Jordan, the Platform Architect (Secondary)

| Attribute | Description |
|-----------|-------------|
| **Role** | Staff Engineer / Platform Architect at an enterprise |
| **Experience** | 8+ years; responsible for data platform strategy |
| **Goal** | Evaluate Expanso for enterprise adoption; needs to see advanced patterns (multi-cloud, compliance) |
| **Context** | Making buy/build decisions; needs to assess Expanso's capability ceiling |
| **Current Behavior** | Reads architecture sections first, looks for production deployment examples, seeks compliance evidence. Presents findings to leadership. |
| **Pain Points** | Existing examples too basic; needs evidence of enterprise-grade patterns; concerned about security and compliance |
| **Success Looks Like** | Presents Expanso to leadership with concrete examples of GDPR compliance and multi-cloud routing, leading to a formal proof-of-concept |

### Persona 4: Casey, the Community Contributor (Secondary)

| Attribute | Description |
|-----------|-------------|
| **Role** | Experienced Expanso user and active community member |
| **Experience** | Expert in Expanso; built multiple production pipelines |
| **Goal** | Contribute expertise, learn advanced patterns from peers, gain recognition |
| **Current Behavior** | Reviews contribution guidelines first, tests examples locally before submitting, values detailed feedback. Active in forums but has no structured outlet for contributions. |
| **Pain Points** | No structured way to share and validate complex pipeline designs; existing examples don't challenge them |
| **Success Looks Like** | Submits a new template, receives feedback, and sees it merged with attribution |

---

## User Stories / Use Cases

### Getting Started (Alex)
- **US-1**: As Alex, I want to find a ready-to-run template for reading from a file and printing output, so that I can verify my Expanso installation works in under 5 minutes.
- **US-2**: As Alex, I want a walkthrough that explains Bloblang mapping syntax step-by-step, so that I understand how to transform data for my specific use case.
- **US-3**: As Alex, I want templates for common cloud integrations (Kafka→S3, Kafka→Snowflake), so that I can prototype my use case without writing YAML from scratch.

### Production Readiness (Sam)
- **US-4**: As Sam, I want a template that implements a dead-letter queue with retry logic, so that I can ensure my production pipeline handles failures gracefully.
- **US-5**: As Sam, I want a walkthrough on PII masking patterns, so that I can comply with data privacy requirements before deploying to production.
- **US-6**: As Sam, I want all templates to use environment variables for secrets, so that I can safely integrate them into my CI/CD pipeline without leaking credentials.

### Enterprise Evaluation (Jordan)
- **US-7**: As Jordan, I want to see an advanced template for multi-cloud routing (AWS and Azure and GCP), so that I can evaluate Expanso's capability for our hybrid infrastructure.
- **US-8**: As Jordan, I want a GDPR/CCPA compliance walkthrough, so that I can present a compliance strategy to our legal team.
- **US-9**: As Jordan, I want to see production-grade patterns (circuit breakers, observability), so that I can assess Expanso for mission-critical workloads.

### Community (Casey)
- **US-10**: As Casey, I want a clear contribution guide with CI validation, so that I can submit new templates and receive feedback efficiently.
- **US-11**: As Casey, I want to see my contributions attributed in the repository, so that I'm recognized for my expertise.

---

## Functional Requirements

### Templates
1. The repository MUST contain at least 25 production-ready pipeline templates.
2. Each template MUST be a single, valid YAML file executable with `expanso-edge run` with only environment variable configuration required.
3. Templates MUST be categorized by primary function: Inputs, Outputs, Transformations, Patterns.
4. Templates MUST cover all three major cloud providers: AWS, GCP, and Azure.
5. All templates MUST pass validation via `expanso-cli job validate` on the main branch.
6. Each template MUST include a header comment block with: name, description, components used, documentation links, usage instructions, and required environment variables.
7. Any template requiring credentials MUST include a prominent `## SECURITY WARNING` comment block directing users to the secret management walkthrough.

### Walkthroughs
8. The repository MUST contain at least 20 in-depth walkthroughs.
9. Each walkthrough MUST include: README.md with explanations, complete pipeline.yaml, sample test data, and expected output for validation.
10. Walkthroughs MUST be organized into progressive tracks (Getting Started → Transformations → Routing → Security → Integrations → Advanced).
11. **Every walkthrough MUST map to at least one corresponding, executable template in the repository.** Conceptual walkthroughs without a runnable example are out of scope.
12. Walkthroughs MUST cross-reference related templates and other walkthroughs.

### Quality & Validation
13. The repository MUST include a CI/CD pipeline (GitHub Actions) that validates all YAML files on every commit and PR.
14. The repository MUST include a pre-commit hook script for local validation.
15. The repository MUST block merges of invalid configurations.

### Contribution
16. The repository MUST include a CONTRIBUTING.md with clear guidelines for proposing and submitting new content.
17. Community contributions MUST follow an issue-first process (propose before PR).
18. The repository MUST be public and accept community contributions under a permissive license (Apache 2.0 or MIT).

### Discoverability
19. The repository README MUST provide clear navigation with a progressive learning path.
20. The repository MUST be linked from the official Expanso documentation.
21. Template and walkthrough names MUST be search-friendly and descriptive.

---

## Non-Functional Requirements

1. **Reliability**: 100% of templates on main branch pass validation at all times.
2. **Maintainability**: Repository structure follows a defined schema: new templates added to `/templates/<category>/`, new walkthroughs to `/walkthroughs/<track>/`, with updates to a central `INDEX.md` file.
3. **Performance**: CI validation completes in under 5 minutes.
4. **Clarity**: Beginner-track walkthroughs (Tracks 1 & 2) must assume no prior Expanso knowledge and avoid undocumented jargon.
5. **Currency**: All content is validated for compatibility with the latest stable Expanso release within 30 days of that release.

---

## Success Metrics / KPIs

### Measurement Approach

All metrics require baseline establishment during a 4-week pre-launch measurement period. Post-launch metrics are compared against this baseline to determine impact. Attribution is established through:
- **Direct measurement**: User surveys embedded in walkthroughs
- **Comparative analysis**: Pre/post launch ticket volume with consistent tagging
- **GitHub analytics**: Native traffic data

| Metric | Description | Baseline Method | Target | Post-Launch Measurement |
|--------|-------------|-----------------|--------|------------------------|
| **Repository Traffic** | Unique visitors per month | N/A (new repo) | >500/month by month 3 | GitHub traffic analytics |
| **Template Downloads** | Raw YAML file views/clones per month | N/A (new repo) | >200/month by month 3 | GitHub traffic analytics |
| **Time-to-First-Pipeline** | Time for new user to deploy working pipeline | Pre-launch user testing with 5 Alex-persona users (measure baseline without repo) | Reduce by 50% (from estimated 4+ hours to <2 hours) | Post-onboarding survey: "How long did it take to run your first pipeline using this repo?" |
| **Support Ticket Deflection** | Reduction in "example request" support tickets | Tag and count "example request" tickets for 3 months pre-launch | 20% reduction by month 6 | Compare tagged ticket volume post-launch |
| **Community Contributions** | Non-maintainer PRs merged | N/A (new repo) | >3 merged PRs in first 6 months | GitHub Insights |
| **Content Freshness** | % of content validated against latest Expanso release | N/A | 100% within 30-day SLA | CI pipeline report / audit log |

---

## Scope

### In Scope

| Category | Included |
|----------|----------|
| **Content** | 25 YAML pipeline templates, 20 markdown walkthroughs. **Every walkthrough has a corresponding runnable template.** |
| **Infrastructure** | CI/CD validation pipeline, pre-commit hooks |
| **Documentation** | README navigation, CONTRIBUTING.md, template/walkthrough standards |
| **Cloud Coverage** | AWS (S3, Kinesis, SQS), GCP (BigQuery, Pub/Sub, GCS), Azure (Blob Storage, Event Hubs) |
| **Patterns** | Basic I/O, transformations, routing, fan-out, error handling, security/compliance, observability |
| **Community** | Contribution process, issue templates, PR review guidelines |

### Out of Scope

| Category | Excluded | Rationale |
|----------|----------|-----------|
| **UI/Web App** | No browsing interface beyond GitHub. No Visual Builder or Expanso Cloud console integration. | Keep scope focused on CLI-based, open-source content |
| **Video Content** | No video tutorials | Different skill set; can be added later based on demand |
| **Interactive Sandboxes** | No hosted execution environments | Requires infrastructure investment; separate product |
| **1:1 Support** | No custom pipeline development | Repository is self-service |
| **Version Forks** | No maintenance of old Expanso versions | Users expected to use latest stable |
| **Replacing Documentation** | Does not replace component reference docs | Complements, not replaces |
| **Conceptual-Only Guides** | Walkthroughs without runnable templates | Ensures immediate user value; prevents documentation drift |

---

## Dependencies

| Dependency | Description | Risk Level | Impact if Unavailable |
|------------|-------------|------------|----------------------|
| **expanso-cli** | Validation command must be publicly available and stable | Low | Cannot validate; fall back to manual testing |
| **expanso-edge** | Templates must be executable with current release | Low | Templates untestable |
| **GitHub Actions** | CI/CD platform for validation | Low | Minor effort to use alternative CI |
| **Expanso Documentation** | Walkthroughs link to component docs | Medium | Broken links reduce UX; requires coordination |
| **Expanso Releases** | Breaking changes require template updates | Medium | Content drift; mitigated by maintenance process |

---

## Risks and Mitigations

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| **Low Community Contribution** | Medium | High | Proactively recruit early contributors from forum power users; implement "good first issue" labels; recognize contributors in README Hall of Fame; promote in community channels and release announcements |
| **Content Drift / Staleness** | High | Medium | **Defined maintenance process:** Primary and secondary maintainer per track. Quarterly calendar-triggered review. Weekly CI runs against Expanso `main` branch to detect breaking changes. Each template includes `last_validated` metadata. |
| **User Confusion with Official Docs** | Low | Medium | Clear positioning as "cookbook" vs "reference manual"; explicit linking strategy (cookbook→docs for components, docs→cookbook for examples). Joint launch announcement with docs team. |
| **Templates Used Insecurely** | Low | High | **Mandatory security warnings** (FR#7). Obvious placeholders (`YOUR_API_KEY_HERE`). Dedicated "Secret Management" walkthrough. Security checklist in CONTRIBUTING.md. |
| **Overwhelming Complexity for Beginners** | Medium | Medium | Clear progressive learning path in README; prominent "Start Here" section; visual separation of beginner/advanced tracks; beginner content passes readability review. |
| **Azure Integration Complexity** | Medium | Low | Start with common Azure services (Blob, Event Hubs); expand based on demand and contributor input. |

---

## Content Specification

### Templates (25 Production-Ready YAMLs)

#### Category 1: Basic Input/Output (Templates 1-6)
| # | Template Name | Components | Description |
|---|---------------|------------|-------------|
| 1 | `file-to-stdout.yaml` | file → stdout | Simplest pipeline - read file, print output |
| 2 | `http-webhook.yaml` | http_server → file | Receive webhooks, write to timestamped files |
| 3 | `kafka-consumer.yaml` | kafka → stdout | Consume Kafka topic with SASL auth |
| 4 | `s3-reader.yaml` | aws_s3 → stdout | Read objects from S3 bucket |
| 5 | `mqtt-sensor.yaml` | mqtt → stdout | IoT sensor data ingestion |
| 6 | `generate-test-data.yaml` | generate → stdout | Synthetic data generation for testing |

#### Category 2: Cloud Outputs (Templates 7-14)
| # | Template Name | Components | Description |
|---|---------------|------------|-------------|
| 7 | `to-s3.yaml` | stdin → aws_s3 | Write to S3 with date partitioning |
| 8 | `to-bigquery.yaml` | stdin → gcp_bigquery | Stream to BigQuery table |
| 9 | `to-snowflake.yaml` | stdin → snowflake | Load into Snowflake |
| 10 | `to-splunk.yaml` | stdin → splunk_hec | Send logs to Splunk HEC |
| 11 | `to-datadog.yaml` | stdin → datadog | Metrics and logs to Datadog |
| 12 | `to-elasticsearch.yaml` | stdin → elasticsearch | Index documents to Elasticsearch |
| 13 | `to-azure-blob.yaml` | stdin → azure_blob_storage | Write to Azure Blob Storage |
| 14 | `to-azure-eventhubs.yaml` | stdin → azure_event_hubs | Stream to Azure Event Hubs |

#### Category 3: Transformations (Templates 15-18)
| # | Template Name | Components | Description |
|---|---------------|------------|-------------|
| 15 | `json-transform.yaml` | stdin → mapping → stdout | Bloblang field mapping and filtering |
| 16 | `log-parser.yaml` | stdin → grok → stdout | Parse unstructured logs to JSON |
| 17 | `csv-to-json.yaml` | stdin → csv → stdout | Convert CSV to JSON records |
| 18 | `schema-validation.yaml` | stdin → json_schema → stdout | Validate against JSON Schema |

#### Category 4: Patterns (Templates 19-25)
| # | Template Name | Components | Description |
|---|---------------|------------|-------------|
| 19 | `fan-out.yaml` | kafka → broker (fan_out) → [s3, elasticsearch] | Multi-destination routing |
| 20 | `content-routing.yaml` | http → switch → [kafka, file] | Route by field values |
| 21 | `pii-masking.yaml` | stdin → mapping → stdout | Detect and mask PII |
| 22 | `circuit-breaker.yaml` | kafka → try → [primary, fallback] | Failure handling with fallback |
| 23 | `dead-letter-queue.yaml` | kafka → try → [output, dlq] | DLQ pattern with retries |
| 24 | `multi-cloud-routing.yaml` | http → switch → [s3, gcs, azure_blob] | Route to cloud by region/tenant |
| 25 | `field-encryption.yaml` | stdin → mapping → stdout | AES field-level encryption |

### Walkthroughs (20 In-Depth Tutorials)

**Every walkthrough maps to one or more of the 25 defined templates.**

#### Track 1: Getting Started (Walkthroughs 1-3)
| # | Title | Concepts | Maps to Templates |
|---|-------|----------|-------------------|
| 1 | Your First Pipeline | Pipeline anatomy, running with `expanso-edge run` | 1, 6 |
| 2 | Understanding Bloblang | Mapping syntax, field access, functions | 15 |
| 3 | From Template to Cloud | Adapting a template, environment variables, deployment to S3 | 7, 13 |

#### Track 2: Data Transformations (Walkthroughs 4-7)
| # | Title | Concepts | Maps to Templates |
|---|-------|----------|-------------------|
| 4 | Parsing Logs at the Edge | Grok patterns, multiline, severity extraction | 16 |
| 5 | Structured Data Transformation | Advanced Bloblang: conditionals, error handling, type coercion | 15 |
| 6 | Format Conversion Pipeline | CSV to JSON, schema validation | 17, 18 |
| 7 | Enrichment with Cache | Using the `cache` processor for lookups | 15 (enhanced) |

#### Track 3: Routing & Distribution (Walkthroughs 8-11)
| # | Title | Concepts | Maps to Templates |
|---|-------|----------|-------------------|
| 8 | Fan-Out to Multiple Destinations | Broker outputs, parallel processing | 19 |
| 9 | Content-Based Routing | Switch processor, conditional outputs | 20 |
| 10 | Dead Letter Queues & Retries | Error handling, retry strategies, DLQ patterns | 23 |
| 11 | Cross-Region Data Distribution | Multi-cloud routing, latency optimization | 24 |

#### Track 4: Security & Compliance (Walkthroughs 12-15)
| # | Title | Concepts | Maps to Templates |
|---|-------|----------|-------------------|
| 12 | Secret Management | Environment variables, secure configuration | All templates |
| 13 | PII Detection and Masking | Regex patterns, redaction strategies | 21 |
| 14 | Field-Level Encryption | AES encryption, key management concepts | 25 |
| 15 | Building a Compliance Pipeline | Combining PII masking, encryption, audit outputs | 21, 25, 1 |

#### Track 5: Cloud Integrations (Walkthroughs 16-18)
| # | Title | Concepts | Maps to Templates |
|---|-------|----------|-------------------|
| 16 | AWS Integration Suite | S3 input/output, credential configuration | 4, 7 |
| 17 | GCP Integration Suite | BigQuery streaming, Pub/Sub patterns | 8 |
| 18 | Azure Integration Suite | Blob Storage, Event Hubs patterns | 13, 14 |

#### Track 6: Advanced Patterns (Walkthroughs 19-20)
| # | Title | Concepts | Maps to Templates |
|---|-------|----------|-------------------|
| 19 | Circuit Breakers & Fallbacks | Failure isolation, graceful degradation | 22 |
| 20 | Production-Grade Pipeline Blueprint | Combining DLQs, circuit breakers, monitoring | 22, 23 |

---

## Prioritization

### Phase 1: Foundation
**Scope**: Templates 1-6, Walkthroughs 1-3, CI/CD setup, CONTRIBUTING.md
**Rationale**: Essential for new user onboarding; establishes repository structure and validation

### Phase 2: Core Integrations & Transformations
**Scope**: Templates 7-18, Walkthroughs 4-7, 16-18
**Rationale**: Most common production use cases; covers all three major clouds

### Phase 3: Production Patterns
**Scope**: Templates 19-23, Walkthroughs 8-11, 19-20
**Rationale**: Addresses production-readiness requirements (error handling, routing)

### Phase 4: Security & Advanced
**Scope**: Templates 24-25, Walkthroughs 12-15
**Rationale**: Enterprise-grade security, compliance, and multi-cloud patterns

---

## Key Decisions

| Decision | Rationale |
|----------|-----------|
| **Every walkthrough requires a runnable template** | Ensures immediate user value (executable code); maintains single source of truth |
| **No UI/Cloud console guides** | Keeps scope focused on CLI-based open-source tooling; proprietary UI docs would drift |
| **Security warnings are mandatory** | Proactively mitigates high-impact risk of insecure usage |
| **Success measured by user outcomes** | KPIs focus on actionable signals (time saved, tickets deflected) with explicit baselines |
| **Maintenance process is defined** | Mitigates high-probability content drift with clear ownership and cadence |
| **Azure included from start** | Enterprise users require multi-cloud coverage |

---

## References

- [Expanso Documentation](https://docs.expanso.io/)
- [Expanso Examples](https://examples.expanso.io/)
- [Components Reference](https://docs.expanso.io/components/)
- [Bloblang Guide](https://docs.expanso.io/getting-started/core-concepts/)
- [Pipeline Examples](https://docs.expanso.io/examples/)
