(function() {
  "use strict";

  if (!window.LeafletWidget || !window.LeafletWidget.methods || !window.L) {
    throw new Error("leaflet.indoor requires the Leaflet htmlwidget binding.");
  }

  var STATE_KEY = "__leaflet_indoor_state_v1__";

  function ownState(map) {
    if (!Object.prototype.hasOwnProperty.call(map, STATE_KEY)) {
      Object.defineProperty(map, STATE_KEY, {
        value: {
          datasets: Object.create(null),
          controls: Object.create(null)
        },
        enumerable: false,
        configurable: false,
        writable: false
      });
    }
    return map[STATE_KEY];
  }

  function mergeOptions(base, extra, common) {
    var output = {};
    var key;
    base = base || {};
    extra = extra || {};
    common = common || {};
    for (key in base) if (Object.prototype.hasOwnProperty.call(base, key)) output[key] = base[key];
    for (key in common) if (Object.prototype.hasOwnProperty.call(common, key) && common[key] !== null) output[key] = common[key];
    for (key in extra) if (Object.prototype.hasOwnProperty.call(extra, key)) output[key] = extra[key];
    return output;
  }

  function featureDefaults(feature, options) {
    var type = feature && feature.geometry ? feature.geometry.type : "";
    var base = type === "Point" || type === "MultiPoint" ? options.point :
      (type === "LineString" || type === "MultiLineString" ? options.line : options.polygon);
    var output = mergeOptions(base, feature.properties.leafletIndoorStyle, {
      pane: options.pane,
      interactive: options.interactive
    });
    var internalClass = "leaflet-indoor-feature leaflet-indoor-feature-" +
      String(feature.properties.leafletIndoorIndex);
    output.className = output.className ? output.className + " " + internalClass : internalClass;
    return output;
  }

  function sendShinyInput(map, suffix, payload) {
    var Shiny = window.Shiny;
    if (!Shiny) return;
    var id = map.getContainer().id + suffix;
    if (typeof Shiny.setInputValue === "function") {
      Shiny.setInputValue(id, payload, {priority: "event"});
    } else if (typeof Shiny.onInputChange === "function") {
      Shiny.onInputChange(id, payload);
    }
  }

  function featureClick(map, dataset, level, properties, event) {
    var latlng = event && event.latlng ? event.latlng : null;
    sendShinyInput(map, "_indoor_feature_click", {
      id: properties.leafletIndoorLayerId,
      dataset_id: dataset.id,
      level: level,
      lat: latlng ? latlng.lat : null,
      lng: latlng ? latlng.lng : null
    });
  }

  function layerForFeature(map, dataset, level, feature) {
    var props = feature.properties || {};
    return L.geoJSON(feature, {
      style: function(part) {
        return featureDefaults(part, dataset.options);
      },
      pointToLayer: function(part, latlng) {
        return L.circleMarker(latlng, featureDefaults(part, dataset.options));
      },
      onEachFeature: function(part, layer) {
        if (props.leafletIndoorLabel !== null && props.leafletIndoorLabel !== undefined) {
          layer.bindTooltip(props.leafletIndoorLabel, dataset.labelOptions || {});
        }
        if (props.leafletIndoorPopup !== null && props.leafletIndoorPopup !== undefined) {
          layer.bindPopup(props.leafletIndoorPopup, dataset.popupOptions || {});
        }
        layer.on("click", function(event) {
          featureClick(map, dataset, level, props, event);
        });
      }
    });
  }

  function removeActiveLayer(map, dataset) {
    if (!dataset || dataset.active === null || dataset.active === undefined) return;
    var group = dataset.groups[dataset.active];
    if (group && map.hasLayer(group)) map.removeLayer(group);
  }

  function updateLinkedControls(map, datasetId) {
    var state = ownState(map);
    Object.keys(state.controls).forEach(function(controlId) {
      var entry = state.controls[controlId];
      if (entry.datasetId === datasetId) entry.control.refresh();
    });
  }

  function addDataset(map, payload) {
    var state = ownState(map);
    var previous = state.datasets[payload.datasetId];
    removeActiveLayer(map, previous);

    var dataset = {
      id: payload.datasetId,
      levels: payload.levels || [],
      active: payload.initialLevel === undefined ? null : payload.initialLevel,
      groups: Object.create(null),
      options: payload.options || {},
      labelOptions: payload.labelOptions || {},
      popupOptions: payload.popupOptions || {},
      crs: payload.crs
    };
    dataset.levels.forEach(function(level) {
      dataset.groups[level] = L.featureGroup();
    });

    var features = payload.geojson && payload.geojson.features ? payload.geojson.features : [];
    features.forEach(function(feature) {
      var levels = feature.properties.leafletIndoorLevels || [];
      if (!Array.isArray(levels)) levels = [levels];
      levels.forEach(function(level) {
        if (dataset.groups[level]) {
          dataset.groups[level].addLayer(layerForFeature(map, dataset, level, feature));
        }
      });
    });

    state.datasets[payload.datasetId] = dataset;
    if (dataset.active !== null && dataset.groups[dataset.active]) {
      dataset.groups[dataset.active].addTo(map);
    }
    updateLinkedControls(map, payload.datasetId);
  }

  function setLevel(map, datasetId, level, userInitiated, controlId) {
    var state = ownState(map);
    var dataset = state.datasets[datasetId];
    if (!dataset) {
      console.error("leaflet.indoor: unknown dataset_id " + JSON.stringify(datasetId) + ".");
      return false;
    }
    if (dataset.levels.indexOf(level) === -1) {
      console.error("leaflet.indoor: unknown level " + JSON.stringify(level) +
        " for dataset_id " + JSON.stringify(datasetId) + ".");
      return false;
    }
    if (dataset.active !== level) {
      removeActiveLayer(map, dataset);
      dataset.active = level;
      dataset.groups[level].addTo(map);
      updateLinkedControls(map, datasetId);
    }
    if (userInitiated) {
      sendShinyInput(map, "_indoor_level", {
        level: level,
        dataset_id: datasetId,
        control_id: controlId
      });
    }
    return true;
  }

  var IndoorControl = L.Control.extend({
    initialize: function(map, settings) {
      this._indoorMap = map;
      this._settings = settings;
      L.setOptions(this, {position: settings.position});
    },

    onAdd: function() {
      var container = L.DomUtil.create("div", "leaflet-control leaflet-bar leaflet-indoor-control");
      container.setAttribute("data-indoor-control-id", this._settings.controlId);
      container.setAttribute("data-indoor-dataset-id", this._settings.datasetId);
      var heading = L.DomUtil.create("div", "leaflet-indoor-control__title", container);
      heading.textContent = this._settings.title;
      this._group = L.DomUtil.create("div", "leaflet-indoor-control__levels", container);
      this._group.setAttribute("role", "radiogroup");
      this._group.setAttribute("aria-label", this._settings.title);
      this._group.style.maxHeight = String(this._settings.maxHeight) + "px";
      L.DomEvent.disableClickPropagation(container);
      L.DomEvent.disableScrollPropagation(container);
      this._container = container;
      this.refresh();
      return container;
    },

    refresh: function() {
      if (!this._group) return;
      var restoreFocus = this._group.contains(document.activeElement);
      while (this._group.firstChild) this._group.removeChild(this._group.firstChild);
      var state = ownState(this._indoorMap);
      var dataset = state.datasets[this._settings.datasetId];
      var levels = dataset ? dataset.levels.slice() : [];
      var active = dataset ? dataset.active : null;
      if (this._settings.descending) levels.reverse();
      if (levels.length === 0) {
        var empty = L.DomUtil.create("div", "leaflet-indoor-control__empty", this._group);
        empty.textContent = this._settings.emptyLabel;
        return;
      }
      var self = this;
      var buttons = [];
      levels.forEach(function(level) {
        var button = L.DomUtil.create("button", "leaflet-indoor-control__button", self._group);
        button.type = "button";
        button.setAttribute("role", "radio");
        button.setAttribute("data-indoor-level", level);
        button.setAttribute("aria-checked", level === active ? "true" : "false");
        button.tabIndex = level === active ? 0 : -1;
        button.textContent = level;
        if (level === active) L.DomUtil.addClass(button, "leaflet-indoor-control__button--active");
        L.DomEvent.on(button, "click", function(event) {
          L.DomEvent.preventDefault(event);
          setLevel(self._indoorMap, self._settings.datasetId, level, true, self._settings.controlId);
        });
        buttons.push(button);
      });
      buttons.forEach(function(button, index) {
        L.DomEvent.on(button, "keydown", function(event) {
          var target = null;
          if (event.key === "ArrowUp" || event.key === "ArrowLeft") {
            target = (index - 1 + buttons.length) % buttons.length;
          } else if (event.key === "ArrowDown" || event.key === "ArrowRight") {
            target = (index + 1) % buttons.length;
          } else if (event.key === "Home") {
            target = 0;
          } else if (event.key === "End") {
            target = buttons.length - 1;
          }
          if (target !== null) {
            L.DomEvent.preventDefault(event);
            var next = buttons[target];
            var nextLevel = next.getAttribute("data-indoor-level");
            setLevel(self._indoorMap, self._settings.datasetId,
              nextLevel, true, self._settings.controlId);
            var refreshed = self._group.querySelectorAll("button");
            for (var i = 0; i < refreshed.length; i++) {
              if (refreshed[i].getAttribute("data-indoor-level") === nextLevel) {
                refreshed[i].focus();
                break;
              }
            }
          }
        });
      });
      if (restoreFocus) {
        for (var i = 0; i < buttons.length; i++) {
          if (buttons[i].getAttribute("aria-checked") === "true") {
            buttons[i].focus();
            break;
          }
        }
      }
    }
  });

  function addControl(map, payload) {
    var state = ownState(map);
    var previous = state.controls[payload.controlId];
    if (previous) map.removeControl(previous.control);
    var control = new IndoorControl(map, payload);
    state.controls[payload.controlId] = {
      control: control,
      datasetId: payload.datasetId
    };
    control.addTo(map);
  }

  function removeControl(map, controlId) {
    var state = ownState(map);
    var entry = state.controls[controlId];
    if (!entry) return;
    map.removeControl(entry.control);
    delete state.controls[controlId];
  }

  function clearDataset(map, datasetId) {
    var state = ownState(map);
    var dataset = state.datasets[datasetId];
    removeActiveLayer(map, dataset);
    state.datasets[datasetId] = {
      id: datasetId,
      levels: [],
      active: null,
      groups: Object.create(null),
      options: dataset ? dataset.options : {},
      labelOptions: dataset ? dataset.labelOptions : {},
      popupOptions: dataset ? dataset.popupOptions : {}
    };
    updateLinkedControls(map, datasetId);
  }

  window.LeafletWidget.methods["leafletIndoor.add"] = function(payload) {
    addDataset(this, payload);
  };
  window.LeafletWidget.methods["leafletIndoor.addControl"] = function(payload) {
    addControl(this, payload);
  };
  window.LeafletWidget.methods["leafletIndoor.setLevel"] = function(payload) {
    setLevel(this, payload.datasetId, payload.level, false, null);
  };
  window.LeafletWidget.methods["leafletIndoor.removeControl"] = function(payload) {
    removeControl(this, payload.controlId);
  };
  window.LeafletWidget.methods["leafletIndoor.clear"] = function(payload) {
    clearDataset(this, payload.datasetId);
  };
})();
