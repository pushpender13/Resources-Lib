import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { showComposer } from "discourse/lib/composer";
import { hbs } from "ember-cli-htmlbars";

export default class ResourceLibrary extends Component {
  @tracked activeRoot = null;
  @tracked tree = [];
  @tracked topicsMap = {};
  @tracked search = "";

  ROOTS = [
    { id: 10, slug: "resource-library", label: "All Resources" },
    { id: 61, slug: "california-resource-library", label: "California Resources" }
  ];

  constructor() {
    super(...arguments);
    this.init();
  }

  async init() {
    this.activeRoot = this.ROOTS[0];
    await this.loadTree(this.activeRoot.id);
  }

  async loadTree(rootId) {
    const res = await ajax(`/c/${rootId}/show.json`);
    const categories = res.category_list.categories;

    this.tree = this.buildTree(categories, rootId);
    await this.loadTopics();
  }

  buildTree(categories, rootId) {
    const map = {};

    categories.forEach(c => {
      map[c.id] = { ...c, children: [] };
    });

    categories.forEach(c => {
      if (c.parent_category_id && map[c.parent_category_id]) {
        map[c.parent_category_id].children.push(map[c.id]);
      }
    });

    return Object.values(map).filter(c => c.parent_category_id === rootId);
  }

  async loadTopics() {
    let map = {};

    for (let cat of this.flatten(this.tree)) {
      const res = await ajax(`/c/${cat.id}/l/latest.json?per_page=5`);
      map[cat.id] = res.topic_list.topics;
    }

    this.topicsMap = map;
  }

  flatten(nodes) {
    let out = [];
    nodes.forEach(n => {
      out.push(n);
      if (n.children?.length) {
        out = out.concat(this.flatten(n.children));
      }
    });
    return out;
  }

  @action
  async switchRoot(root) {
    this.activeRoot = root;
    await this.loadTree(root.id);
  }

  @action
  newResource() {
    showComposer(this, {
      action: "createTopic",
      categoryId: this.activeRoot.id,
      allowedCategoryIds: this.getAllowedIds()
    });
  }

  getAllowedIds() {
    return [
      this.activeRoot.id,
      ...this.flatten(this.tree).map(c => c.id)
    ];
  }

  @action
  updateSearch(e) {
    this.search = e.target.value.toLowerCase();
  }

  filter(topics) {
    if (!this.search) return topics;
    return topics.filter(t =>
      t.title.toLowerCase().includes(this.search)
    );
  }

  static template = hbs`
    <div class="custom-resource-page">

      <div class="header">
        {{#each this.ROOTS as |root|}}
          <button
            class={{if (eq root.id this.activeRoot.id) "active"}}
            {{on "click" (fn this.switchRoot root)}}
          >
            {{root.label}}
          </button>
        {{/each}}

        <input
          placeholder="Search resources..."
          {{on "input" this.updateSearch}}
        />

        <button {{on "click" this.newResource}}>
          + New Resource
        </button>
      </div>

      <div class="tree">
        {{#each this.tree as |cat|}}
          <CategoryNode
            @cat={{cat}}
            @topics={{this.topicsMap}}
            @filter={{this.filter}}
          />
        {{/each}}
      </div>

    </div>
  `;
}
