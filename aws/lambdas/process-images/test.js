const {getClient, getOriginalImage, processImage, uploadProcessedImage} = require('./s3-image-processing.js')

async function main(){
  client = getClient()
  // change the bucket names to YOURS
  const srcBucket = 'THUMBIN BUCKET NAME'
  const srcKey = 'avatar/original/data.jpg'
  const dstBucket = 'THUMBIN BUCKET NAME'
  const dstKey = 'avatar/processed/data.png'
  const width = 256
  const height = 256

  const originalImage = await getOriginalImage(client,srcBucket,srcKey)
  console.log(originalImage)
  const processedImage = await processImage(originalImage,width,height)
  await uploadProcessedImage(client,dstBucket,dstKey,processedImage)
}

main()