import { type RouteConfig, index, route, layout } from "@react-router/dev/routes";

export default [
  layout("components/Layout.tsx", [
    index("pages/Home.tsx"),
    route("changelog", "pages/Changelog.tsx"),
    route("docs", "pages/Docs.tsx"),
    route("feature-requests", "pages/FeatureRequests.tsx"),
    route("success", "pages/Success.tsx"),
  ]),
] satisfies RouteConfig;
