import 'package:polymer/polymer.dart';
import 'dart:html';
import 'dart:async';
import 'dart:math';
import 'package:woven/src/client/app.dart';
import 'package:woven/config/config.dart';
import 'package:woven/src/shared/input_formatter.dart';
import 'package:firebase/firebase.dart' as db;
import 'package:core_elements/core_input.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:woven/src/shared/model/activity_comment.dart';

@CustomTag('item-activities')
class ItemActivities extends PolymerElement {
  @published App app;
  @observable List comments = toObservable([]);
  @observable ActivityCommentModel comment;
  @observable Map theData = toObservable({
    'name': '',
    'comment': ''
  });

  var firebaseLocation = config['datastore']['firebaseLocation'];

  String formatItemDate(DateTime value) {
    return InputFormatter.formatMomentDate(value, short: true, momentsAgo: true);
  }

  getActivities() {
    var itemId;
    // If there's no app.selectedItem, we probably
    // came here directly, so let's use itemId from the URL.
    if (app.selectedItem == null) {
      // Decode the base64 URL and determine the item.
      var base64 = Uri.parse(window.location.toString()).pathSegments[1];
      var bytes = CryptoUtils.base64StringToBytes(base64);
      itemId = UTF8.decode(bytes);
    } else {
      itemId = app.selectedItem['id'];
    }

    var f = new db.Firebase(firebaseLocation + '/items/' + itemId + '/activities/comments');
    f.onChildAdded.listen((e) {
      var comment = e.snapshot.val();
      comment['createdDate'] = DateTime.parse(comment['createdDate']);
      comment['id'] = e.snapshot.name();

      // Insert each new item at top of list so the list is ascending.
      comments.insert(0, comment);
    });
  }

  //
  // Add a comment to /activities/comments for this item.
  //
  addComment(Event e, var detail, Element target) {
    e.preventDefault();

    String name = theData['name'];
    name = name.trim();
    String comment = theData['comment'];
    comment = comment.trim();

    if (name.isEmpty) {
      window.alert("Your name is empty.");
      return false;
    }
    if (comment.isEmpty) {
      window.alert("Your comment is empty.");
      return false;

    }

    var itemId = app.selectedItem['id'];

    DateTime now = new DateTime.now().toUtc();

    var root = new db.Firebase(config['datastore']['firebaseLocation']);
    var id = root.child('/items/' + itemId + '/activities/comments').push();
    var commentJson =  {'user': name, 'comment': comment, 'createdDate': '$now'};

    // Set the item in multiple places because denormalization equals speed.
    // We also want to be able to load the item when we don't know the community.
    Future setComment(db.Firebase commentRef) {
      commentRef.set(commentJson).then((e){
        var nameRef = id.name();
        root.child('/items/' + app.community.alias + '/' + itemId + '/activities/comments/' + nameRef)
          ..set(commentJson);
      });
    }

    setComment(id);

    // Update some details on the parent item.
    var parent = root.child('/items/' + itemId);

    Future updateParentItem(db.Firebase parentRef) {
      parent.update({
        'updatedDate': '$now'
      }).then((e) {
        root.child('/items/' + app.community.alias + '/' + itemId).update({
            'updatedDate': '$now'
        });
      });
    }

    updateParentItem(parent);

    // Reset the fields.
    comment.inputValue = "";
    // TODO: Focus the field: http://goo.gl/wDYQOx
  }

  signInWithFacebook() {
    app.signInWithFacebook();
  }

  attached() {
    print("+ItemActivities");
    getActivities();
  }

  detached() {
    print("-ItemActivities");
  }

  ItemActivities.created() : super.created();
}
