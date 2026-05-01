import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { service } from "@ember/service";
import { eq } from "truth-helpers";
import { ajax } from "discourse/lib/ajax";
import Composer from "discourse/models/composer";
import CategoryNode from "./category-node";

export default class ResourceLibrary extends Component {
  @service composer;
  @service site;

  @tracked activeRootId = 10;
  @tracked categories = [];
  @tracked topicsMap = {};
  @tracked searchQuery = "";
  @tracked loading = true;

  ROOTS = [
    { id: 10, label: "All Resources" },
    { id: 61, label: "California Resources" },
  ];

  constructor() {
    super(...arguments);
    this.loadData();
  }

  async loadData() {
    this.loading = true;
    this.topicsMap = {};
    this.categories = [];

    try {
      const allCategories = this.site.categories || [];
      const children = allCategories.filter(
        (c) => c.parent_category_id === this.activeRootId
      );

      const tree = children.map((parent) => {
        const subs = allCategories.filter(
          (c) => c.parent_category_id === parent.id
        );
        return {
          ...parent,
          subcategories: subs.map((sub) => {
            const subSubs = allCategories.filter(
              (c) => c.parent_category_id === sub.id
            );
            return { ...sub, subcategories: subSubs };
          }),
        };
      });

      this.categories = tree;
      await this.loadAllTopics(tree);
    } catch (e) {
      // eslint-disable-next-line no-console
      console.error("ResourceLibrary: failed to load", e);
    } finally {
      this.loading = false;
    }
  }

  async loadAllTopics(tree) {
    const leafCategories = this.getLeafCategories(tree);
    const map = {};

    const batches = [];
    for (let i = 0; i < leafCategories.length; i += 5) {
      batches.push(leafCategories.slice(i, i + 5));
    }

    for (const batch of batches) {
      const results = await Promise.all(
        batch.map((cat) =>
          ajax(`/c/${cat.slug}/${cat.id}/l/latest.json?per_page=5`)
            .then((res) => ({ id: cat.id, topics: res.topic_list.topics }))
            .catch(() => ({ id: cat.id, topics: [] }))
        )
      );
      results.forEach((r) => {
        map[r.id] = r.topics;
      });
    }

    this.topicsMap = map;
  }

  getLeafCategories(tree) {
    const leaves = [];
    const walk = (nodes) => {
      nodes.forEach((n) => {
        if (n.subcategories && n.subcategories.length > 0) {
          walk(n.subcategories);
        } else {
          leaves.push(n);
        }
      });
    };
    walk(tree);
    return leaves;
  }

  @action
  switchRoot(root) {
    this.activeRootId = root.id;
    this.searchQuery = "";
    this.loadData();
  }

  @action
  onSearchInput(e) {
    this.searchQuery = e.target.value;
  }

  get allowedCategoryIds() {
    const allCategories = this.site.categories || [];
    const allowed = [];
    this.ROOTS.forEach((root) => {
      const firstLevel = allCategories.filter(
        (c) => c.parent_category_id === root.id
      );
      firstLevel.forEach((parent) => {
        const subSubs = allCategories.filter(
          (c) => c.parent_category_id === parent.id
        );
        subSubs.forEach((s) => allowed.push(s.id));
      });
    });
    return allowed;
  }

  @action
  openNewResource() {
    const allowedIds = this.allowedCategoryIds;
    const styleId = "resource-library-composer-filter";
    let styleEl = document.getElementById(styleId);
    if (!styleEl) {
      styleEl = document.createElement("style");
      styleEl.id = styleId;
      document.head.appendChild(styleEl);
    }
    const allowSelectors = allowedIds
      .map((id) => `.category-chooser .category-row[data-value="${id}"]`)
      .join(",\n");
    styleEl.textContent = `.category-chooser .category-row { display: none !important; }\n${allowSelectors} { display: flex !important; }`;

    this.composer.open({
      action: Composer.CREATE_TOPIC,
      draftKey: Composer.CREATE_TOPIC,
      draftSequence: 0,
    });

    this._watchComposerClose();
  }

  _watchComposerClose() {
    const styleId = "resource-library-composer-filter";
    const check = () => {
      const composerEl = document.getElementById("reply-control");
      const isClosed =
        !composerEl || composerEl.classList.contains("closed");
      if (isClosed) {
        const el = document.getElementById(styleId);
        if (el) el.remove();
      } else {
        requestAnimationFrame(check);
      }
    };
    requestAnimationFrame(check);
  }

  get filteredCategories() {
    if (!this.searchQuery.trim()) {
      return this.categories;
    }
    const q = this.searchQuery.toLowerCase();
    return this.filterTree(this.categories, q);
  }

  filterTree(cats, query) {
    return cats
      .map((cat) => {
        const filteredSubs = cat.subcategories
          ? this.filterTree(cat.subcategories, query)
          : [];

        const catTopics = this.topicsMap[cat.id] || [];
        const matchingTopics = catTopics.filter((t) =>
          t.title.toLowerCase().includes(query)
        );

        if (filteredSubs.length > 0 || matchingTopics.length > 0) {
          return { ...cat, subcategories: filteredSubs, _filteredTopics: matchingTopics };
        }
        return null;
      })
      .filter(Boolean);
  }

  <template>
    <div class="resource-library">
      <div class="resource-library__header">
        <h1 class="resource-library__title">Resource Library</h1>
        <p class="resource-library__description">
          Curated reports, briefs, and guides on Medicaid policy — organized by topic for easy reference.
        </p>
      </div>

      <div class="resource-library__controls">
        <div class="resource-library__tabs">
          {{#each this.ROOTS as |root|}}
            <button
              class="resource-library__tab {{if (eq root.id this.activeRootId) 'resource-library__tab--active'}}"
              type="button"
              {{on "click" (fn this.switchRoot root)}}
            >
              {{root.label}}
            </button>
          {{/each}}
        </div>

        <div class="resource-library__actions">
          <div class="resource-library__search">
            <input
              type="text"
              class="resource-library__search-input"
              placeholder="Search resources..."
              value={{this.searchQuery}}
              {{on "input" this.onSearchInput}}
            />
          </div>

          <button
            class="resource-library__new-btn"
            type="button"
            {{on "click" this.openNewResource}}
          >
            + New Resource
          </button>
        </div>
      </div>

      <div class="resource-library__content">
        {{#if this.loading}}
          <div class="resource-library__loading">Loading resources...</div>
        {{else if this.filteredCategories.length}}
          {{#each this.filteredCategories as |cat|}}
            <CategoryNode
              @category={{cat}}
              @topicsMap={{this.topicsMap}}
              @searchQuery={{this.searchQuery}}
              @maxTopics={{5}}
            />
          {{/each}}
        {{else}}
          <div class="resource-library__empty">No resources found.</div>
        {{/if}}
      </div>
    </div>
  </template>
}
