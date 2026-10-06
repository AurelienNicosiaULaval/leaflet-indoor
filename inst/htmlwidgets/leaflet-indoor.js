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

  function replaceCounterTokens(template, current, total) {
    return String(template)
      .replace(/\{current\}/g, String(current))
      .replace(/\{total\}/g, String(total));
  }

  function updatePopupLayout(layer) {
    var popup = layer.getPopup ? layer.getPopup() : null;
    if (popup && typeof popup.update === "function") popup.update();
  }

  function updatePhotoPopupHeight(map, root) {
    var container = map && map.getContainer ? map.getContainer() : null;
    var mapHeight = container ? container.clientHeight : 0;
    if (mapHeight > 0) {
      var maxHeight = Math.max(160, mapHeight - 112);
      root.style.maxHeight = String(maxHeight) + "px";
      var image = root.querySelector(".leaflet-indoor-photo-popup__image");
      if (image && !image.hidden && image.offsetHeight > 0) {
        image.style.maxHeight = "";
        var naturalDisplayHeight = image.offsetHeight;
        var nonImageHeight = root.scrollHeight - naturalDisplayHeight;
        var availableImageHeight = Math.max(72, maxHeight - nonImageHeight);
        image.style.maxHeight = String(
          Math.min(naturalDisplayHeight, availableImageHeight)
        ) + "px";
        root.scrollTop = 0;
      }
    }
  }

  function closePhotoDialog(dataset) {
    if (dataset && typeof dataset.closePhotoDialog === "function") {
      dataset.closePhotoDialog();
    }
  }

  function openPhotoDialog(dataset, photo, trigger) {
    closePhotoDialog(dataset);
    var options = dataset.photoOptions || {};
    var overlay = L.DomUtil.create("div", "leaflet-indoor-photo-dialog");
    overlay.setAttribute("role", "dialog");
    overlay.setAttribute("aria-modal", "true");
    overlay.setAttribute("aria-label", options.dialogLabel || "Enlarged room photo");

    var panel = L.DomUtil.create("div", "leaflet-indoor-photo-dialog__panel", overlay);
    var closeButton = L.DomUtil.create("button", "leaflet-indoor-photo-dialog__close", panel);
    closeButton.type = "button";
    closeButton.textContent = options.closeLabel || "Close";

    var figure = L.DomUtil.create("figure", "leaflet-indoor-photo-dialog__figure", panel);
    var image = L.DomUtil.create("img", "leaflet-indoor-photo-dialog__image", figure);
    image.alt = photo.alt || "";
    var caption = L.DomUtil.create("figcaption", "leaflet-indoor-photo-dialog__caption", figure);
    caption.textContent = photo.caption;
    var unavailable = L.DomUtil.create("div", "leaflet-indoor-photo-dialog__unavailable", figure);
    unavailable.setAttribute("role", "status");
    unavailable.textContent = options.unavailableLabel || "Image unavailable";
    unavailable.hidden = true;

    var closed = false;
    function close() {
      if (closed) return;
      closed = true;
      document.removeEventListener("keydown", onKeydown);
      if (overlay.parentNode) overlay.parentNode.removeChild(overlay);
      if (dataset.closePhotoDialog === close) dataset.closePhotoDialog = null;
      if (trigger && typeof trigger.focus === "function") trigger.focus();
    }
    function onKeydown(event) {
      if (event.key === "Escape") {
        event.preventDefault();
        close();
      } else if (event.key === "Tab") {
        event.preventDefault();
        closeButton.focus();
      }
    }
    closeButton.addEventListener("click", close);
    overlay.addEventListener("click", function(event) {
      if (event.target === overlay) close();
    });
    document.addEventListener("keydown", onKeydown);
    dataset.closePhotoDialog = close;
    document.body.appendChild(overlay);
    image.addEventListener("error", function() {
      image.hidden = true;
      unavailable.hidden = false;
    });
    image.src = photo.src;
    closeButton.focus();
  }

  function createPhotoCarousel(map, dataset, layer, properties) {
    var photos = properties.leafletIndoorPhotos;
    var options = dataset.photoOptions || {};
    var root = L.DomUtil.create("div", "leaflet-indoor-photo-popup");
    root.setAttribute("role", "group");
    root.setAttribute("aria-label", options.carouselLabel || "Room photos");
    root.setAttribute("data-indoor-photo-count", String(photos.length));
    L.DomEvent.disableClickPropagation(root);
    L.DomEvent.disableScrollPropagation(root);

    if (properties.leafletIndoorPopup !== null &&
        properties.leafletIndoorPopup !== undefined) {
      var introduction = L.DomUtil.create("div", "leaflet-indoor-photo-popup__introduction", root);
      introduction.innerHTML = properties.leafletIndoorPopup;
    }

    var figure = L.DomUtil.create("figure", "leaflet-indoor-photo-popup__figure", root);
    var image = L.DomUtil.create("img", "leaflet-indoor-photo-popup__image", figure);
    var caption = L.DomUtil.create("figcaption", "leaflet-indoor-photo-popup__caption", figure);
    var unavailable = L.DomUtil.create("div", "leaflet-indoor-photo-popup__unavailable", figure);
    unavailable.setAttribute("role", "status");
    unavailable.textContent = options.unavailableLabel || "Image unavailable";
    unavailable.hidden = true;

    var counter = L.DomUtil.create("div", "leaflet-indoor-photo-popup__counter", root);
    counter.setAttribute("aria-live", "polite");
    var actions = L.DomUtil.create("div", "leaflet-indoor-photo-popup__actions", root);
    var previous = L.DomUtil.create("button", "leaflet-indoor-photo-popup__button", actions);
    previous.type = "button";
    previous.textContent = options.previousLabel || "Previous";
    var next = L.DomUtil.create("button", "leaflet-indoor-photo-popup__button", actions);
    next.type = "button";
    next.textContent = options.nextLabel || "Next";
    var enlarge = L.DomUtil.create(
      "button",
      "leaflet-indoor-photo-popup__button leaflet-indoor-photo-popup__button--enlarge",
      actions
    );
    enlarge.type = "button";
    enlarge.textContent = options.enlargeLabel || "Enlarge";

    var index = 0;
    function render() {
      var photo = photos[index];
      image.hidden = false;
      unavailable.hidden = true;
      image.alt = photo.alt || "";
      image.src = photo.src;
      caption.textContent = photo.caption;
      counter.textContent = replaceCounterTokens(
        options.counterLabel || "Photo {current} of {total}",
        index + 1,
        photos.length
      );
      root.setAttribute("data-indoor-photo-index", String(index));
      previous.disabled = photos.length < 2;
      next.disabled = photos.length < 2;
      updatePopupLayout(layer);
    }
    image.addEventListener("load", function() {
      updatePopupLayout(layer);
    });
    image.addEventListener("error", function() {
      image.hidden = true;
      unavailable.hidden = false;
      updatePopupLayout(layer);
    });
    previous.addEventListener("click", function(event) {
      event.preventDefault();
      index = (index - 1 + photos.length) % photos.length;
      render();
    });
    next.addEventListener("click", function(event) {
      event.preventDefault();
      index = (index + 1) % photos.length;
      render();
    });
    enlarge.addEventListener("click", function(event) {
      event.preventDefault();
      openPhotoDialog(dataset, photos[index], enlarge);
    });
    updatePhotoPopupHeight(map, root);
    render();
    return root;
  }

  function commentIcon(options) {
    var targetSize = Math.max(44, (options.size || 36) + 8);
    var badge = document.createElement("span");
    badge.className = "leaflet-indoor-comment-marker__badge";
    badge.style.color = options.color || "#ffffff";
    badge.style.backgroundColor = options.backgroundColor || "#7c3aed";
    badge.setAttribute("aria-hidden", "true");
    var paths = {
      comment: "M4 4h16v12H9l-5 4V4z",
      quote: "M4 6h6v6H7v5H4V6zm10 0h6v6h-3v5h-3V6z",
      info: "M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18zm-1 4h2v2h-2V7zm0 4h2v6h-2v-6z"
    };
    var name = options.icon || "comment";
    if (Object.prototype.hasOwnProperty.call(paths, name)) {
      var svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
      svg.setAttribute("viewBox", "0 0 24 24");
      svg.setAttribute("focusable", "false");
      var path = document.createElementNS("http://www.w3.org/2000/svg", "path");
      path.setAttribute("d", paths[name]);
      path.setAttribute("fill", "currentColor");
      path.setAttribute("fill-rule", "evenodd");
      svg.appendChild(path);
      badge.appendChild(svg);
    } else {
      badge.textContent = name;
    }
    return L.divIcon({
      className: "leaflet-indoor-comment-marker",
      html: badge.outerHTML,
      iconSize: [targetSize, targetSize],
      iconAnchor: [targetSize / 2, targetSize / 2],
      popupAnchor: [0, -20]
    });
  }

  function createCommentPopup(dataset, properties) {
    var options = dataset.commentOptions;
    var root = L.DomUtil.create("div", "leaflet-indoor-comment-popup");
    root.setAttribute("role", "region");
    root.setAttribute("aria-label", options.popupLabel || "Room comments");
    root.setAttribute("data-indoor-comment-count", String(properties.leafletIndoorComments.length));
    root.tabIndex = -1;
    var heading = L.DomUtil.create("h3", "leaflet-indoor-comment-popup__heading", root);
    heading.textContent = options.popupLabel || "Room comments";
    if (properties.leafletIndoorLabel) {
      // Room labels are already encoded or explicitly trusted by the R API.
      var room = L.DomUtil.create("div", "leaflet-indoor-comment-popup__room", root);
      room.innerHTML = properties.leafletIndoorLabel;
    }
    properties.leafletIndoorComments.forEach(function(comment) {
      var article = L.DomUtil.create("article", "leaflet-indoor-comment-popup__entry", root);
      if (comment.title) {
        var title = L.DomUtil.create("h4", "leaflet-indoor-comment-popup__title", article);
        title.textContent = comment.title;
      }
      var text = L.DomUtil.create("p", "leaflet-indoor-comment-popup__text", article);
      text.textContent = comment.text;
      var attribution = [comment.author, comment.date].filter(function(value) { return Boolean(value); });
      if (attribution.length) {
        var byline = L.DomUtil.create("div", "leaflet-indoor-comment-popup__byline", article);
        byline.textContent = attribution.join(" · ");
      }
      if (comment.source && /^https?:\/\//i.test(comment.source)) {
        var link = L.DomUtil.create("a", "leaflet-indoor-comment-popup__source", article);
        link.href = comment.source;
        link.textContent = options.sourceLabel || "Read source";
        link.target = "_blank";
        link.rel = "noopener noreferrer";
      }
    });
    L.DomEvent.disableClickPropagation(root);
    L.DomEvent.disableScrollPropagation(root);
    return root;
  }

  function commentMarkerForFeature(map, dataset, level, feature, roomLayer) {
    var properties = feature.properties;
    var options = dataset.commentOptions;
    var comments = properties.leafletIndoorComments;
    var position = properties.leafletIndoorCommentPosition;
    if (options.show === false || !Array.isArray(comments) || !comments.length || !position) return null;
    var label = options.markerLabel || "Read room comments";
    if (properties.leafletIndoorLabel) {
      var decoded = document.createElement("div");
      decoded.innerHTML = properties.leafletIndoorLabel;
      label += ": " + decoded.textContent;
    }
    var marker = L.marker([position.lat, position.lng], {
      icon: commentIcon(options),
      title: label,
      keyboard: true,
      interactive: dataset.options.interactive !== false,
      bubblingMouseEvents: false
    });
    var root = createCommentPopup(dataset, properties);
    marker.bindPopup(root, mergeOptions({maxWidth: 360, keepInView: true}, dataset.popupOptions));
    function syncIconSize() {
      var element = marker.getElement();
      if (!element) return;
      var size = options.size || 36;
      if (options.fitToRoom !== false && !/^(Multi)?Point$/.test(feature.geometry.type)) {
        var bounds = roomLayer.getBounds();
        if (bounds.isValid() && bounds.getEast() !== bounds.getWest() &&
            bounds.getNorth() !== bounds.getSouth() && typeof map.getZoom() === "number") {
          // Project without rounding so small rooms keep shrinking at distant zooms.
          var northwest = map.project(bounds.getNorthWest(), map.getZoom());
          var southeast = map.project(bounds.getSouthEast(), map.getZoom());
          var roomSize = Math.min(Math.abs(southeast.x - northwest.x),
            Math.abs(southeast.y - northwest.y));
          size = Math.max(options.minSize || 12, Math.min(size, roomSize * 0.75));
        }
      }
      var badge = element.querySelector(".leaflet-indoor-comment-marker__badge");
      badge.style.width = String(size) + "px";
      badge.style.height = String(size) + "px";
      badge.style.fontSize = String(size * 0.6) + "px";
      badge.style.borderWidth = String(Math.max(1, size / 18)) + "px";
      // Keep the pointer of an open popup attached to the visual badge.
      marker.options.icon.options.popupAnchor = [0, -size / 2];
      if (marker.isPopupOpen()) updatePopupLayout(marker);
    }
    function syncLayout() {
      root.style.maxHeight = String(Math.max(96, map.getContainer().clientHeight - 130)) + "px";
      var popup = marker.getPopup();
      popup.options.maxWidth = Math.min(dataset.popupOptions.maxWidth || 360,
        Math.max(100, map.getContainer().clientWidth - 80));
      updatePopupLayout(marker);
    }
    marker.on("add", function() {
      var element = marker.getElement();
      element.setAttribute("role", "button");
      element.setAttribute("aria-label", label);
      element.setAttribute("aria-expanded", "false");
      element.setAttribute("data-indoor-comment-id", properties.leafletIndoorLayerId);
      syncIconSize();
      map.on("zoomend resize", syncIconSize);
      if (dataset.options.interactive === false) element.tabIndex = -1;
      L.DomEvent.on(element, "keydown", function(event) {
        if (event.key === " " && dataset.options.interactive !== false) {
          L.DomEvent.stop(event);
          marker.fire("click", {latlng: marker.getLatLng()});
        }
      });
    });
    marker.on("remove", function() {
      map.off("zoomend resize", syncIconSize);
    });
    marker.on("popupopen", function() {
      marker.getElement().setAttribute("aria-expanded", "true");
      syncLayout();
      map.on("resize", syncLayout);
      root.focus({preventScroll: true});
    });
    marker.on("popupclose", function() {
      map.off("resize", syncLayout);
      var element = marker.getElement();
      if (element) {
        element.setAttribute("aria-expanded", "false");
        if (element.isConnected && root.contains(document.activeElement)) element.focus({preventScroll: true});
      }
    });
    L.DomEvent.on(root, "keydown", function(event) {
      if (event.key === "Escape") {
        L.DomEvent.stop(event);
        var element = marker.getElement();
        marker.closePopup();
        if (element && element.isConnected) element.focus({preventScroll: true});
      }
    });
    marker.on("click", function() {
      sendShinyInput(map, "_indoor_comment_click", {
        id: properties.leafletIndoorLayerId,
        dataset_id: dataset.id,
        level: level,
        lat: position.lat,
        lng: position.lng,
        comment_count: comments.length
      });
    });
    return marker;
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
        var hasPhotos = Array.isArray(props.leafletIndoorPhotos) &&
          props.leafletIndoorPhotos.length > 0;
        if (hasPhotos) {
          var carousel = createPhotoCarousel(map, dataset, layer, props);
          function syncPhotoPopupLayout() {
            updatePhotoPopupHeight(map, carousel);
            updatePopupLayout(layer);
          }
          layer.bindPopup(
            carousel,
            dataset.popupOptions || {}
          );
          layer.on("popupopen", function() {
            L.DomUtil.addClass(map.getContainer(), "leaflet-indoor-photo-popup-open");
            syncPhotoPopupLayout();
            map.on("resize", syncPhotoPopupLayout);
          });
          layer.on("popupclose", function() {
            map.off("resize", syncPhotoPopupLayout);
            L.DomUtil.removeClass(map.getContainer(), "leaflet-indoor-photo-popup-open");
            closePhotoDialog(dataset);
          });
        } else if (props.leafletIndoorPopup !== null && props.leafletIndoorPopup !== undefined) {
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
    closePhotoDialog(dataset);
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
      photoOptions: payload.photoOptions || {},
      commentOptions: payload.commentOptions || {},
      closePhotoDialog: null,
      crs: payload.crs
    };
    // htmlwidgets serializes a single floor name as a scalar string.
    if (!Array.isArray(dataset.levels)) dataset.levels = [dataset.levels];
    dataset.levels.forEach(function(level) {
      dataset.groups[level] = L.featureGroup();
    });

    var features = payload.geojson && payload.geojson.features ? payload.geojson.features : [];
    features.forEach(function(feature) {
      var levels = feature.properties.leafletIndoorLevels || [];
      if (!Array.isArray(levels)) levels = [levels];
      levels.forEach(function(level) {
        if (dataset.groups[level]) {
          var roomLayer = layerForFeature(map, dataset, level, feature);
          dataset.groups[level].addLayer(roomLayer);
          var commentMarker = commentMarkerForFeature(map, dataset, level, feature, roomLayer);
          if (commentMarker) dataset.groups[level].addLayer(commentMarker);
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
      popupOptions: dataset ? dataset.popupOptions : {},
      photoOptions: dataset ? dataset.photoOptions : {},
      closePhotoDialog: null
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
