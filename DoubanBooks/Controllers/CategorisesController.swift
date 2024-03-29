//
//  CategorisesController.swift
//  DoubanBooks
//
//  Created by 2017yd on 2019/10/18.
//  Copyright © 2019年 2017yd. All rights reserved.
//
import UIKit

private let reuseIdentifier = "categoryCell"

class CategorisesController: UICollectionViewController ,EmptyViewDelegate{
    
    
    var categories: [VMCategoty]?
    
    let addCategorySegu = "addCategorySegu"
    let BooksSegu = "BooksSegu"
    let factory = CategotyFactory.getInstance(UIApplication.shared.delegate as! AppDelegate)
    
    var isEmpty: Bool{
        get{
            if let data  = categories {
                return data.count == 0
            }
            return true
        }
    }
    var imgEmpty:UIImageView?
    func createEmptyView() -> UIView? {
        if let empty = imgEmpty{
            return empty
        }
        let w = UIScreen.main.bounds.width
        let h = UIScreen.main.bounds.height
        let batHeigHt = navigationController?.navigationBar.frame.height
        let img = UIImageView(frame: CGRect(x: (w-139)/2, y: (h-128)/2 - (batHeigHt ?? 0), width:139, height: 128))
        img.image = UIImage(named: "no_data")
        img.contentMode = .scaleAspectFit
        return img
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        do{
          categories = try factory.getAllCategories()
        }catch DataError.readCollectionError(let info){
            categories = [VMCategoty]()
            UIAlertController.showALertAndDismiss(info, in: self)
        }catch{
            categories = [VMCategoty]()
        }
        /// selector：要做什么
        NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: NSNotification.Name(rawValue: notiCategory), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reload), name: NSNotification.Name(rawValue: navigations), object: nil)
        let lpTap = UILongPressGestureRecognizer(target: self, action: #selector(longPressSwitch(_:)))
        collectionView.addGestureRecognizer(lpTap)
        let tap = UITapGestureRecognizer(target: self, action:  #selector(tapToStopShakingOrBooksSegur(_:)))
        collectionView.addGestureRecognizer(tap)
        collectionView.setEmtpyCollectionViewDelegate(target: self)
    }
    /// 接受数据
    @objc func refresh(noti: Notification){
        //刷新
        ///使用键来获取值
        let name = noti.userInfo!["name"] as! String
        do{
            categories?.removeAll()
            categories?.append(contentsOf: try factory.getAllCategories())
            UIAlertController.showALertAndDismiss("\(name)添加成功！", in: self, completion: {
                self.navigationController?.popViewController(animated: true)
                self.collectionView.reloadData()
                })

        }catch DataError.readCollectionError(let info){
            categories = [VMCategoty]()
            UIAlertController.showALertAndDismiss(info, in: self)
        }catch{
            categories = [VMCategoty]()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func reload(){
        collectionView.reloadData()
    }
    
    var longPressed = false {
        // longPressed改变后刷新
        didSet{
            if oldValue != longPressed{
                collectionView.reloadData()
            }
        }
    }
    var point :CGPoint?
    /// 长按
    @objc func longPressSwitch (_ lpTap: UILongPressGestureRecognizer ){
        // 如果长按（在item上）就进入删除模式
        //判断是否点在item上
        point = lpTap.location(in: collectionView)
        
        if let p = point, let _ = collectionView.indexPathForItem(at: p){
                longPressed = true
        }
        
    }
    
    @objc func tapToStopShakingOrBooksSegur(_ tap: UITapGestureRecognizer){
        // 1. 停止删除模式
        // 2. 点击item的时候就执行books场景过度
        // 识别当前的点
        point = tap.location(in: collectionView)
        if let p = point, collectionView.indexPathForItem(at: p) == nil {
            longPressed = false
        }
        if let p = point , let index = collectionView .indexPathForItem(at: p) {
            if !longPressed{
                performSegue(withIdentifier: BooksSegu, sender: index.item)
            }
        }
    }
    
    @objc func deleteCategory(_ :Int){
        
        UIAlertController.showConfirm("确定删除？", in: self, confirm: {_ in
            let index = self.collectionView.indexPathForItem(at: self.point!)
            let category = self.categories![index!.item]
           let (sueeccrr, error) =  self.factory.removeCategory(category: category)
            if !sueeccrr{
                UIAlertController.showALertAndDismiss(error!, in: self)
            } else {
                self.categories?.remove(at: index!.item)
            }
            let fileManager = FileManager.default
            do{
            try fileManager.removeItem(atPath: NSHomeDirectory().appending(imgDir).appending(category.image!))
            }catch{
                UIAlertController.showALertAndDismiss("删除失败", in: self)
            }
            self.longPressed = false
            self.collectionView.reloadData()
        })
        
    }
    
    
    
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }


    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of items
        return categories!.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! CategoryCell
        let category = categories![indexPath.item]
        cell.lblName.text = category.name!
        cell.lblCount.text = String(factory.getBooksCountOfCategory(category: category.id)!)
        // TODO: 图库文件保存到沙盒，取文件地址
        cell.imgCover.image = UIImage(contentsOfFile: NSHomeDirectory().appending(imgDir).appending(category.image!))
        cell.lblEditTime.text = CategotyFactory.getEditTimeFromPlist(id: category.id)
        // 添加按钮的点击事件
        
        // TODO 删除模式下抖动，非删除模式取消抖动
        if longPressed{
            //删除模式下抖动
            let pos = collectionView.indexPathForItem(at: point!)?.item
            if pos == indexPath.item{
                cell.btnDelete.isHidden = false
                let anim = CABasicAnimation(keyPath: "transform.rotation")
                anim.toValue = -Double.pi / 64
                anim.fromValue = Double.pi / 64
                anim.duration = 0.15
                anim.repeatCount = MAXFLOAT
                anim.autoreverses = true
                cell.layer.add(anim, forKey: "SpringboardShake")
            }
            
            cell.btnDelete.addTarget(self, action: #selector(deleteCategory(_:)), for: .touchUpInside)
           
        }else{
            //非删除模式取消抖动
            // TODO:随普通模式和删除模式切换可见
            cell.btnDelete.isHidden = true
        }
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(gotoFindTab(_:)))
        cell.imgInfo.isUserInteractionEnabled = true
        cell.imgInfo.addGestureRecognizer(tap)
        cell.imgInfo.tag = indexPath.item
        
        return cell
    }
    
    
    // TODO: 场景跳转
    @objc func gotoFindTab(_ tap: UITapGestureRecognizer) {
        if let pos = tap.view?.tag {
            let findController = tabBarController?.viewControllers![1] as! FindControllerController
            findController.category = categories![pos]
            findController.kws = categories![pos].name!
            findController.loadBooks(kw: categories![pos].name!)
            tabBarController?.selectedIndex = 1
            tabBarController?.selectedViewController?.tabBarItem.badgeValue = categories![pos].name
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == BooksSegu {
            let destinatons = segue.destination as! BooksController
            if sender is Int {
                let categories = self.categories![sender as! Int]
                destinatons.categories = categories
            }
        }
        
        
    }
    
    
    // MARK: UICollectionViewDelegate

    /*
    // Uncomment this method to specify if the specified item should be highlighted during tracking
    override func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        return true
    }
    */

    /*
    // Uncomment this method to specify if the specified item should be selected
    override func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        UIAlertController.showALertAndDismiss("\(indexPath.row)", in: self)
        return true
    }
    */

    /*
    // Uncomment these methods to specify if an action menu should be displayed for the specified item, and react to actions performed on the item
    override func collectionView(_ collectionView: UICollectionView, shouldShowMenuForItemAt indexPath: IndexPath) -> Bool {
        return false
    }

    override func collectionView(_ collectionView: UICollectionView, canPerformAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) -> Bool {
        return false
    }

    override func collectionView(_ collectionView: UICollectionView, performAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) {
    
    }
    */
    

}
