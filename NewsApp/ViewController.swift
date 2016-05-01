//
//  ViewController.swift
//  NewsApp
//
//  Created by Anton Morozov on 30.04.16.
//  Copyright © 2016 Anton Morozov. All rights reserved.
//

import UIKit
import SafariServices

enum NewsURLKey {
  static let Topstories = "topstories"
  static let Item = "item"
}

struct News {

  let title: String
  let url: NSURL?
  let time: NSDate

  init(snapshot: FDataSnapshot) {

    // title
    self.title = ((snapshot.value["title"] as? String) != nil) ? snapshot.value["title"] as! String : ""

    // url
    if let urlStr = snapshot.value["url"] as? String where urlStr.isEmpty == false {
      url = NSURL(string: urlStr)
    } else {
      url = nil
    }

    // time
    if let time = snapshot.value["time"] as? Double where time > 0 {
      self.time = NSDate(timeIntervalSince1970:time)
    } else {
      self.time = NSDate()
    }
  }
}

class ViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, SFSafariViewControllerDelegate {

  @IBOutlet weak var tableView: UITableView!
  
  var firebase: Firebase!
  var newsArr = [News]()
  let newsLimit: UInt = 50
  let tableMinRowHeight: CGFloat = 30
  let cellIdentifier = "NewsCell"
  let baseNewsUrl = "https://hacker-news.firebaseio.com/v0/"
  let titleFont = UIFont.systemFontOfSize(14, weight: UIFontWeightMedium)
  let timeFont = UIFont.systemFontOfSize(12, weight: UIFontWeightLight)
  let hPadding: CGFloat = 5.0

  override func viewDidLoad() {
    super.viewDidLoad()

    self.tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: cellIdentifier)

    loadStories()
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }

  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    firebase = Firebase(url: baseNewsUrl)
  }

  //**********************
  // Class
  private func loadStories() {

    // display HUD
    SVProgressHUD.setDefaultMaskType(SVProgressHUDMaskType.Gradient)
    SVProgressHUD.showWithStatus("Loading")

    // Get news
    let query = firebase.childByAppendingPath(NewsURLKey.Topstories).queryLimitedToFirst(newsLimit)
    query.observeSingleEventOfType(.Value, withBlock: { snapshot in
      if let snapshot = snapshot.value as? [Int] {
        var counter: Int = 0
        self.newsArr.removeAll()
        for newsId in snapshot {

          let query = self.firebase.childByAppendingPath(NewsURLKey.Item).childByAppendingPath(String(newsId))
          query.observeSingleEventOfType(.Value, withBlock: { (currNewsSnap) in
            counter = counter + 1

            let news = News(snapshot: currNewsSnap)
            self.newsArr.append(news)

            if snapshot.count == counter {
              self.showData()
            }

            }, withCancelBlock: { (error) in
              counter = counter + 1
              if snapshot.count == counter {
                self.showData()
              }
          })
        }
      } else {
        self.showData()
      }

      }) { (error) in
        self.showData()
    }
  }

  func showData() {

    // sort array by date
    newsArr.sortInPlace({ $0.time.compare($1.time) == NSComparisonResult.OrderedDescending })

    // reload table
    self.tableView.reloadData()

    // hide indicator
    SVProgressHUD.dismiss()
  }

  //**********************
  // MARK: UITableViewDelegate, UITableViewDataSource
  func numberOfSectionsInTableView(tableView: UITableView) -> Int {
    return 1
  }

  func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return newsArr.count
  }

  func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {

    let cell = tableView.dequeueReusableCellWithIdentifier(cellIdentifier, forIndexPath: indexPath) as UITableViewCell

    cell.prepareForReuse()
    cell.contentView.subviews.forEach({ $0.removeFromSuperview() })
    cell.accessoryType = .DisclosureIndicator

    let news = newsArr[indexPath.row]

    // title
    let titleFontAttributes = [ NSFontAttributeName: titleFont ]
    let titleSize = news.title.boundingRectWithSize(CGSizeMake(tableView.frame.size.width * 0.9 , CGFloat.max), options: NSStringDrawingOptions.UsesLineFragmentOrigin, attributes:titleFontAttributes, context:nil).size

    let titleLabel = UILabel(frame: CGRect(x: hPadding, y: hPadding, width: titleSize.width, height: titleSize.height))
    titleLabel.tag = 1
    titleLabel.font = titleFont
    titleLabel.numberOfLines = 0
    titleLabel.text = news.title
    titleLabel.sizeToFit()
    cell.contentView.addSubview(titleLabel)

    // time
    let timeLabel = UILabel(frame: CGRect(x: hPadding, y: titleLabel.frame.size.height + titleLabel.frame.origin.y + hPadding, width: tableView.frame.size.width, height: 14))
    timeLabel.tag = 1
    timeLabel.font = timeFont
    timeLabel.numberOfLines = 0
    timeLabel.text = timeAgoSinceDate(news.time, numericDates: false)
    timeLabel.sizeToFit()
    cell.contentView.addSubview(timeLabel)

    return cell
  }

  func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
    tableView.deselectRowAtIndexPath(indexPath, animated: true)

    let news = newsArr[indexPath.row]
    if let url = news.url  {
      let safariVC = SFSafariViewController(URL: url)
      safariVC.delegate = self
      presentViewController(safariVC, animated: true, completion: nil)
    }
  }

  func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {

    let news = newsArr[indexPath.row]

    let titleFontAttributes = [ NSFontAttributeName: titleFont ]
    let titleSize = news.title.boundingRectWithSize(CGSizeMake(tableView.frame.size.width * 0.9 , CGFloat.max), options: NSStringDrawingOptions.UsesLineFragmentOrigin, attributes:titleFontAttributes, context:nil).size

    var h = hPadding * 3
    h = h + titleSize.height
    h = h + timeFont.lineHeight

    return tableMinRowHeight > h ? tableMinRowHeight : h
  }

  //**********************
  // MARK: SFSafariViewControllerDelegate
  func safariViewControllerDidFinish(controller: SFSafariViewController) {
    controller.dismissViewControllerAnimated(true, completion: nil)
  } 
}
