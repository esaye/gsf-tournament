// Copyright © 2012 John J. Chew, III <poslfit@gmail.com>
// All Rights Reserved.
//
// Dynamic rendition of traditional TSH reports and more

//*** TSHPane

function TSHPane(argh) {
  }

TSHPane.prototype.Render = function (argh) { return 'Render() not overridden'; }

// to be called every 0.05 s
TSHPane.prototype.Tick = function (ticks) {
  var i, l;
  if (!this.frequency) { this.frequency = 1; }
  if (ticks % this.frequency) { return; }
  if (this.subpanes) {
    for (i=0, l=this.subpanes.length; i<l; i++) {
      this.subpanes[i].Tick(ticks);
      }
    }
  if (this.TickAction) {
    try { this.TickAction(ticks); }
    catch (e) { error('TickAction() failed: '+e); }
    }
  };

//*** TSHScoreCard

TSHScoreCard.prototype = new TSHPane();

function TSHScoreCard (argh) {
  this.dname = argh.dname;
  this.pn = argh.pn;
  this.Reload();
  }

TSHScoreCard.prototype.Reload(argh) {
  this.tourney = argh.tourney;
  this.dp = TournamentGetDivisionByName(this.tourney, this.dname);
  this.p = DivisionPlayer(this.dp, this.pn);
  }

TSHScoreCard.prototype.Render(argh) {
  return PlayerName(this.p);
  }

