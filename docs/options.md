---
title: Options
---

# {{ $frontmatter.title }}

<script setup>
import { data } from "./mnw.data.js";
import { RenderDocs } from "easy-nix-documentation";
</script>

<RenderDocs :options="data" :exclude="/programs\.mnw\.providers\.*/" />

## Provider Configuration

<RenderDocs :options="data" :include="/programs\.mnw\.providers\.*/" />
